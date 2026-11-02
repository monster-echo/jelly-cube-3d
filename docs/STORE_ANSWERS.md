# Store Answers — Draft

These are draft answers to copy into the consoles after the final build is verified.

## Apple App Privacy

- Tracking: No.
- Data collected: None.
- Data linked to the user: None.
- Third-party advertising: None.
- Analytics: None.
- Purchases: processed by Apple; the app receives entitlement status only.

## Google Play Data Safety

- Does your app collect or share required user data types? **No.**
- Is all user data encrypted in transit? **N/A** (no developer data collection; store billing uses the store service).
- Do you provide a way for users to request data deletion? **N/A** (no developer account/data).
- Ads: **No.**
- App access: **All functionality available without login**; paid cube types via Play Billing.
- Content rating: Everyone / 4+; no violence, gambling, user-generated content, or mature content.
- Target audience: general audience; not designed for children under 13.
- Financial info: payment is processed by Google Play; developer does not receive card data.

## Huawei AppGallery

- Privacy: no developer data collection; store billing for optional IAP.
- Permissions: no INTERNET for gameplay; no location/camera/microphone.
- Age rating: 4+ / Everyone.
- Region: global excluding mainland China for v1.
- IAP: configure IAP Kit only if extra cube types are sold on HarmonyOS.

## Review notes (short)

> No account required. The app is offline for gameplay. The only network use is the optional store purchase/restore flow. 2×2, 3×3 and 4×4 are free; the non-consumable Extra Cube Types unlock provides 5×5, 6×6 and future extra cube types. Test with a store sandbox account. Restore Purchases is available from the purchase sheet.
