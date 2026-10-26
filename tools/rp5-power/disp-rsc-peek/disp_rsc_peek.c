// SPDX-License-Identifier: GPL-2.0
/*
 * disp_rsc_peek (holodor, 2026-10-18): DEBUG ONLY, read-only. Dumps the DISPLAY RSC that mainline never touches:
 * DRV0 at 0xaf20000 (vendor DT: qcom,rpmh-rsc drv-id 0, tcs-offset 0x1c00, tcs-config = 1 SLEEP + 1 WAKE TCS) and the
 * RSCC wrapper at 0xaf30000. On Android, sde_rsc programs this block (sequencer, solver, sleep/wake votes for mmcx and the
 * display BCMs) and the AOP only sleeps once this DRV is idle. Upstream has no driver for it, so whatever UEFI's splash
 * left in it stands for the whole Linux session. This module shows what is there.
 *
 * Register map: rpmh-rsc.c ver-2.7 offsets (the same RSC IP as the APPS RSC at 0x18200000) + the vendor sde_rsc_hw.h
 * (solver / sequencer / wrapper offsets). Safety: the block is behind disp_cc_mdss_rscc_ahb_clk inside the MDSS GDSC on
 * the mmcx rail; this module takes the RSCC AHB + vsync clocks from the dispcc provider and REFUSES to read unless
 * disp_cc_mdss_ahb_clk is already on (= the display is active, GDSC on, mmcx up). Clocks are taken only for the
 * duration of a dump (a prepared branch would hold the XO vote through suspend). Never read this block via /dev/mem
 * (2026-10-17: an unclocked MMIO read hung the SoC).
 *
 *   insmod disp_rsc_peek.ko            -> DRV0 dump in dmesg + /sys/kernel/debug/disp_rsc_peek/dump
 *   insmod disp_rsc_peek.ko wrapper=1  -> also the wrapper block (second step, in case its clocking differs)
 */
#include <linux/clk.h>
#include <linux/clk-provider.h>
#include <linux/debugfs.h>
#include <linux/io.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/seq_file.h>

#define DRV_BASE	0xaf20000
#define DRV_SIZE	0x10000
#define WRAP_BASE	0xaf30000
#define WRAP_SIZE	0x1000
#define TCS_OFFSET	0x1c00
#define TCS_STRIDE	672
#define CMD_STRIDE	20
#define MAX_TCS		4
#define MAX_CMDS	16

/* dt-bindings/clock/qcom,dispcc-sm8250.h */
#define DISP_CC_MDSS_AHB_CLK		0
#define DISP_CC_MDSS_RSCC_AHB_CLK	42
#define DISP_CC_MDSS_RSCC_VSYNC_CLK	43

static bool wrapper;
module_param(wrapper, bool, 0444);
MODULE_PARM_DESC(wrapper, "also dump the RSCC wrapper block at 0xaf30000");

static void __iomem *drv;
static void __iomem *wrap;
static struct clk *mdss_ahb, *rscc_ahb, *rscc_vsync;
static struct dentry *dir;

#define R(off) readl_relaxed(drv + (off))

struct reg { u32 off; const char *name; };
static const struct reg drv_regs[] = {
	{ 0x000, "RSC_DRV_ID" }, { 0x004, "DRV_SOLVER_CONFIG" }, { 0x00c, "DRV_PRNT_CHLD_CONFIG" },
	{ 0x020, "PDC_SEQ_START_ADDR" }, { 0x024, "PDC_MATCH_VALUE_LO" }, { 0x028, "PDC_MATCH_VALUE_HI" },
	{ 0x02c, "PDC_SLAVE_ID" }, { 0x0d0, "ERROR_IRQ_STATUS" }, { 0x404, "SEQ_BUSY" }, { 0x408, "SEQ_PROGRAM_COUNTER" },
	{ 0x410, "SEQ_CFG_BR_ADDR_0" }, { 0x414, "SEQ_CFG_BR_ADDR_1" }, { 0xc00, "TIMERS_CONSIDERED" },
	{ 0xc04, "SOFT_WAKEUP_TIME_LO" }, { 0xc08, "SOFT_WAKEUP_TIME_HI" }, { 0xc0c, "MAX_IDLE_DURATION" },
	{ 0xc14, "SOLVER_OVERRIDE_CTRL" }, { 0xc18, "SOLVER_OVERRIDE_MODE" }, { 0xc1c, "SOLVER_OVERRIDE_IDLE_TIME" },
	{ 0xc20, "SOLVER_MODES_ENABLED" }, { 0xc24, "SOLVER_STATUS0" }, { 0xc28, "SOLVER_STATUS1(timeslot)" },
	{ 0xc2c, "SOLVER_STATUS2(mode)" }, { 0x1000, "SOLVER_TIME_SLOT_0" }, { 0x1004, "SOLVER_TIME_SLOT_1" },
	{ 0x1008, "SOLVER_TIME_SLOT_2" }, { 0x100c, "SOLVER_TIME_SLOT_3" },
};
static const struct reg wrap_regs[] = {
	{ 0x000, "WRAPPER_CTRL" }, { 0x004, "WRAPPER_OVERRIDE_CTRL" }, { 0x008, "STATIC_WAKEUP_0" },
	{ 0x00c, "RSCC_MODE_THRESHOLD" }, { 0x010, "DEBUG_BUS" }, { 0x018, "VSYNC_TIMESTAMP0" }, { 0x01c, "VSYNC_TIMESTAMP1" },
	{ 0x020, "SPARE_PWR_EVENT" }, { 0x024, "PWR_CTRL" }, { 0x040, "WRAPPER_OVERRIDE_CTRL2" },
	{ 0x044, "MODE_MIN_THRESHOLD" }, { 0x048, "BW_INDICATION" }, { 0x050, "DEBUG_CTRL2" },
};

/* every line goes to both the seq_file (if any) and dmesg */
#define OUT(s, fmt, ...) do { if (s) seq_printf(s, fmt "\n", ##__VA_ARGS__); pr_info(fmt "\n", ##__VA_ARGS__); } while (0)

static int dump(struct seq_file *s)
{
	u32 id, cfg, ntcs, ncpt, i, t, j;
	int ret;

	if (!__clk_is_enabled(mdss_ahb)) {
		OUT(s, "disp_cc_mdss_ahb_clk is OFF: display inactive, MDSS GDSC may be down -> refusing to read");
		return -EBUSY;
	}
	ret = clk_prepare_enable(rscc_ahb);
	if (ret) { OUT(s, "rscc_ahb enable failed %d", ret); return ret; }
	ret = clk_prepare_enable(rscc_vsync);
	if (ret) { OUT(s, "rscc_vsync enable failed %d (continuing)", ret); }

	id = R(0x0);
	cfg = R(0xc);
	ntcs = cfg & 0x3f;	/* rpmh-rsc.c: DRV_NUM_TCS_SHIFT * drv_id, and this is drv 0 */
	ncpt = (cfg >> 27) & 0x1f;
	OUT(s, "disp_rsc DRV0 @%#x: RSC_ID %#010x (v%u.%u) solver_cfg %#010x (hw-solver %u) prnt_chld %#010x -> %u TCS x %u cmds",
	    DRV_BASE, id, (id >> 16) & 0xff, (id >> 8) & 0xff, R(0x4), (R(0x4) >> 24) & 1, cfg, ntcs, ncpt);
	for (i = 0; i < ARRAY_SIZE(drv_regs); i++)
		OUT(s, "  %-28s %#06x = %#010x", drv_regs[i].name, drv_regs[i].off, R(drv_regs[i].off));
	if (ntcs > MAX_TCS) ntcs = MAX_TCS;
	if (ncpt > MAX_CMDS) ncpt = MAX_CMDS;
	for (t = 0; t < ntcs; t++) {
		u32 tb = TCS_OFFSET + TCS_STRIDE * t;
		u32 en = R(tb + 0x1c), ctl = R(tb + 0x14);

		OUT(s, "  TCS%u (%s per vendor DT) @%#x: irq_en %#x irq_status %#x wait_cmpl %#x control %#010x%s status %#x cmd_enable %#06x",
		    t, t == 0 ? "SLEEP" : t == 1 ? "WAKE" : "?", tb, R(tb + 0x0), R(tb + 0x4), R(tb + 0x10), ctl,
		    (ctl & BIT(16)) ? " [AMC-mode]" : "", R(tb + 0x18), en);
		for (j = 0; j < ncpt; j++) {
			u32 cb = tb + CMD_STRIDE * j;
			u32 msgid = R(cb + 0x30), addr = R(cb + 0x34), data = R(cb + 0x38), st = R(cb + 0x3c), resp = R(cb + 0x40);

			if (!(en & BIT(j)) && !addr && !data && !msgid)
				continue;
			OUT(s, "    cmd%-2u %s msgid %#010x addr %#07x data %#010x status %#x resp %#010x",
			    j, (en & BIT(j)) ? "EN " : "dis", msgid, addr, data, st, resp);
		}
	}
	OUT(s, "  SEQ_MEM[0..15]: %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x %08x",
	    R(0x600), R(0x604), R(0x608), R(0x60c), R(0x610), R(0x614), R(0x618), R(0x61c),
	    R(0x620), R(0x624), R(0x628), R(0x62c), R(0x630), R(0x634), R(0x638), R(0x63c));
	if (wrapper && wrap) {
		OUT(s, "disp_rsc WRAPPER @%#x:", WRAP_BASE);
		for (i = 0; i < ARRAY_SIZE(wrap_regs); i++)
			OUT(s, "  %-28s %#06x = %#010x", wrap_regs[i].name, wrap_regs[i].off, readl_relaxed(wrap + wrap_regs[i].off));
	}
	clk_disable_unprepare(rscc_vsync);
	clk_disable_unprepare(rscc_ahb);
	return 0;
}

static int dump_show(struct seq_file *s, void *v) { return dump(s); }
DEFINE_SHOW_ATTRIBUTE(dump);

static struct clk *get_clk(struct device_node *np, u32 idx)
{
	struct of_phandle_args a = { .np = np, .args_count = 1, .args = { idx } };

	return of_clk_get_from_provider(&a);
}

static int __init disp_rsc_peek_init(void)
{
	struct device_node *np = of_find_compatible_node(NULL, NULL, "qcom,sm8250-dispcc");

	if (!np) return -ENODEV;
	mdss_ahb = get_clk(np, DISP_CC_MDSS_AHB_CLK);
	rscc_ahb = get_clk(np, DISP_CC_MDSS_RSCC_AHB_CLK);
	rscc_vsync = get_clk(np, DISP_CC_MDSS_RSCC_VSYNC_CLK);
	of_node_put(np);
	if (IS_ERR(mdss_ahb) || IS_ERR(rscc_ahb) || IS_ERR(rscc_vsync)) {
		pr_err("disp_rsc_peek: dispcc clocks: %d %d %d\n", PTR_ERR_OR_ZERO(mdss_ahb), PTR_ERR_OR_ZERO(rscc_ahb), PTR_ERR_OR_ZERO(rscc_vsync));
		return -ENODEV;
	}
	drv = ioremap(DRV_BASE, DRV_SIZE);
	wrap = ioremap(WRAP_BASE, WRAP_SIZE);
	if (!drv) return -ENOMEM;
	/* no clk_prepare here: a prepared dispcc branch keeps its parents (and the XO vote) prepared through suspend */
	dir = debugfs_create_dir("disp_rsc_peek", NULL);
	debugfs_create_file("dump", 0400, dir, NULL, &dump_fops);
	dump(NULL);
	return 0;
}

static void __exit disp_rsc_peek_exit(void)
{
	debugfs_remove_recursive(dir);
	clk_put(rscc_vsync); clk_put(rscc_ahb); clk_put(mdss_ahb);
	if (wrap) iounmap(wrap);
	iounmap(drv);
}

module_init(disp_rsc_peek_init);
module_exit(disp_rsc_peek_exit);
MODULE_DESCRIPTION("DEBUG: dump the sm8250 display RSC (DRV0 @ 0xaf20000) TCSes and solver state");
MODULE_LICENSE("GPL");
