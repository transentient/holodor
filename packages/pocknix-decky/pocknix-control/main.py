import asyncio

from pocknix_control.config import build_config
from pocknix_control.fan_curves import delete_curve, fan_status, save_curve
from pocknix_control.modes import set_download_inhibit_mode, set_fan_mode, set_lavd_mode, set_power_mode, set_charge_limit, set_led_color, set_led_mode
from pocknix_control.sdcard import detect_sdcard, format_sdcard
from pocknix_control.tweaks import save_tweaks
from pocknix_control.updates import check_updates, start_update, update_status


class Plugin:
    # Offload blocking work to a thread so a slow call can't stall Decky's asyncio loop.
    async def get_config(self):
        return await asyncio.to_thread(build_config)

    async def detect_sdcard(self):
        return await asyncio.to_thread(detect_sdcard)

    async def format_sdcard(self, label):
        return await asyncio.to_thread(format_sdcard, label)

    async def set_fan_mode(self, mode):
        await asyncio.to_thread(set_fan_mode, mode)
        return await self.get_config()

    async def save_fan_curve(self, name, label, curve):
        # Saves (or overwrites) a user curve and makes it the active one.
        saved = await asyncio.to_thread(save_curve, name, label, curve)
        await asyncio.to_thread(set_fan_mode, saved)
        return await asyncio.to_thread(build_config)

    async def delete_fan_curve(self, name):
        await asyncio.to_thread(delete_curve, name)
        return await asyncio.to_thread(build_config)

    async def fan_status(self):
        return await asyncio.to_thread(fan_status)

    async def set_power_mode(self, mode):
        await asyncio.to_thread(set_power_mode, mode)
        return await self.get_config()

    async def set_charge_limit(self, pct):
        await asyncio.to_thread(set_charge_limit, pct)
        return await self.get_config()

    async def set_led_color(self, hexcolor):
        await asyncio.to_thread(set_led_color, hexcolor)
        return await self.get_config()

    async def set_led_mode(self, mode):
        await asyncio.to_thread(set_led_mode, mode)
        return await self.get_config()


    async def set_download_inhibit_mode(self, mode):
        await asyncio.to_thread(set_download_inhibit_mode, mode)
        return await self.get_config()

    async def set_lavd_mode(self, mode):
        await asyncio.to_thread(set_lavd_mode, mode)
        return await self.get_config()

    async def save_tweaks(self, data):
        await asyncio.to_thread(save_tweaks, data)
        return await self.get_config()

    async def check_updates(self):
        return await asyncio.to_thread(check_updates)

    async def start_update(self):
        return await asyncio.to_thread(start_update)

    async def update_status(self):
        return await asyncio.to_thread(update_status)
