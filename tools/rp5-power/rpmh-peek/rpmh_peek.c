// SPDX-License-Identifier: GPL-2.0
/*
 * rpmh_peek (holodor, 2026-10-16): DEBUG ONLY. Reads back the APPS (HLOS) DRV's current RPMh vote for any
 * cmd-db address through rpmh_read() (Qualcomm's posted "soc: qcom: rpmh: Add support to read back resource
 * settings" v5 = holodor kernel patch 0751). Per its author the read returns this DRV's vote, not the
 * aggregate across DRVs: a non-zero vote on a resource Linux never writes = a bootloader leftover.
 *   echo 0x30010 > /sys/kernel/debug/rpmh_peek/addr; cat /sys/kernel/debug/rpmh_peek/value
 * The client device is the RSC's clk-rpmh child (rpmh_read() finds the controller through dev->parent).
 */
#include <linux/debugfs.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_platform.h>
#include <linux/platform_device.h>
#include <soc/qcom/rpmh.h>
#include <soc/qcom/tcs.h>

static struct platform_device *client;
static struct dentry *dir;
static u32 addr;

static int value_get(void *data, u64 *val)
{
	struct tcs_cmd cmd = { .addr = addr };
	int ret;

	if (!addr)
		return -EINVAL;
	ret = rpmh_read(&client->dev, &cmd);
	if (ret)
		return ret;
	*val = cmd.data;
	return 0;
}
DEFINE_DEBUGFS_ATTRIBUTE(value_fops, value_get, NULL, "0x%08llx\n");

static int __init rpmh_peek_init(void)
{
	struct device_node *np = of_find_compatible_node(NULL, NULL, "qcom,sm8250-rpmh-clk");

	if (!np)
		return -ENODEV;
	client = of_find_device_by_node(np);
	of_node_put(np);
	if (!client)
		return -ENODEV;
	dir = debugfs_create_dir("rpmh_peek", NULL);
	debugfs_create_x32("addr", 0600, dir, &addr);
	debugfs_create_file_unsafe("value", 0400, dir, NULL, &value_fops);
	return 0;
}

static void __exit rpmh_peek_exit(void)
{
	debugfs_remove_recursive(dir);
	put_device(&client->dev);
}

module_init(rpmh_peek_init);
module_exit(rpmh_peek_exit);
MODULE_DESCRIPTION("DEBUG: read back the APPS DRV's RPMh votes");
MODULE_LICENSE("GPL");
