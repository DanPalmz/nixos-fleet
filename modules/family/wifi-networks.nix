# Shared profile names and variable references only; credentials belong in SOPS.
# Add any number of entries here. Higher priority wins when networks overlap.
{
  family = {
    ssidVariable = "WIFI_SSID";
    pskVariable = "WIFI_PSK";
    priority = 20;
  };

  # Example second network: uncomment and add both variables to the encrypted
  # environment block in secrets/family-wifi.yaml.
  # farm = {
  #   ssidVariable = "FARM_WIFI_SSID";
  #   pskVariable = "FARM_WIFI_PSK";
  #   priority = 10;
  #   hidden = false;
  # };
}
