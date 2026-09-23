from .fan_curves import list_curves
from .modes import download_inhibit_mode, fan_mode, lavd_mode, power_mode, charge_limit, led_color, led_mode
from .steam import installed_games
from .tweaks import fex_profile_labels, load_fex_contract, load_tweaks


def build_config():
    fex_contract = load_fex_contract()
    return {
        "fanMode": fan_mode(),
        "fanCurves": list_curves(),
        "powerMode": power_mode(),
        "chargeLimit": charge_limit(),
        "ledColor": led_color(),
        "ledMode": led_mode(),
        "lavdMode": lavd_mode(),
        "downloadInhibitMode": download_inhibit_mode(),
        "tweaks": load_tweaks(),
        "fexProfiles": fex_profile_labels(fex_contract),
        "installedGames": installed_games(),
    }
