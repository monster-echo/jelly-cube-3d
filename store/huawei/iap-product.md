# AppGallery — IAP status

**Not implemented.** The current HarmonyOS client shows Extra Cube Types as
locked but has no Huawei IAP Kit purchase path. Do not submit an AppGallery
build that advertises 5×5/6×6 until one of these is true:

1. Huawei IAP Kit is implemented and tested; or
2. The 5×5/6×6 selector is hidden on HarmonyOS and the listing does not
   advertise paid extra types; or
3. The types are made free on HarmonyOS with an explicit product decision.

- Product ID (working): `tech.zhongbei.jellycube3d.extra_types`
- Price: **TBD**
- Required: AGC app record, IAP Kit configuration, signed HAP, sandbox purchase.
