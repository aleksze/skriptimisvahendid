# ============================================================
#  config.example.psd1 — NÄIDISKONFIGURATSIOON
#
#  See fail LÄHEB Gitti. Päris webhook URL ei tohi siin olla!
#
#  Kasutamine:
#    1. Kopeeri see fail nimega config.psd1:
#         Copy-Item config.example.psd1 config.psd1
#    2. Asenda PANE_SIIA_... rida päris URL-iga.
#    3. Veendu, et .gitignore peidab config.psd1 faili:
#         git status   # config.psd1 EI TOHI ilmuda listi
# ============================================================

@{
    # Discord webhook URL kujul:
    # https://discord.com/api/webhooks/<id>/<token>
    WebhookUrl = "PANE_SIIA_DISCORD_WEBHOOK_URL"
}
