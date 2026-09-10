# RideGuard campaign concepts

Open `index.html` for the eight-scene visual review. Artwork is synthetic and explicitly labelled **concept/demo**. It is not a captured screenshot or evidence that the illustrated cloud features are operational.

| Frame | Major benefit | Scene |
| --- | --- | --- |
| 01 | Route choice beyond speed | Morning commuter preparing to leave |
| 02 | Understand the route | Older urban rider in cycling infrastructure |
| 03 | Reported conditions ahead | Delivery rider stopped before roadworks |
| 04 | Hands-free voice interaction | Cyclist with both hands on the handlebars |
| 05 | Let someone know | Evening commuter leaving work |
| 06 | Keep trusted people updated | Contact checking their phone at home |
| 07 | Arrival/check-in | Rider locking a bicycle on arrival |
| 08 | Watch companion | Stationary cyclist’s wrist |

The onboarding source photo is bundled in `App/Assets.xcassets/CyclistHero.imageset`. `app-icon-master.png` is normalized by the build pipeline to the required 1024-pixel square app icon.

## Production export plan

Final artwork needs actual tested app captures composited into these scenarios; remove “planned feature” labels only once those features exist and delivery claims are verified. Replace any generated UI symbols with the native design system and review human anatomy, bicycle geometry, spelling and all implied claims. Do not market an unfinished flow as available.

Capture/export targets selected from [Apple’s current screenshot specification](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/):

- iPhone large portrait: 1320 × 2868.
- iPhone 6.5-inch fallback if needed: 1284 × 2778.
- iPad 13-inch portrait: 2064 × 2752; landscape: 2752 × 2064.
- Watch: 410 × 502, consistently across localisations for that capture set.
- Social concept variants: 1080 × 1350 feed, 1080 × 1920 story; not App Store exports.

The current concept masters are portrait 2:3. **They are not ready for direct App Store upload.** Device-specific layouts must be recomposed, not stretched. Final PNG/JPEG files must be opaque, have legible type and preserve the rider’s hands and the important UI. No device-specific production screenshots or social variants are claimed as completed.

Visual system: deep evergreen, warm ivory, sage, restrained amber; bold benefit-led headline, editorial street photography, large native UI fragments, generous whitespace. Avoid generic phone frames, fear-based copy, neon and excessive glass effects.
