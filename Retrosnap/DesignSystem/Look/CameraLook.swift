import Foundation

// The recipes, one `CameraLook` per camera. `tools/apply_recipes.py` and `tools/pairs.py` read and rewrite this
// switch by pattern: keep each recipe's shape, its 8-space case lines, its literal tint hexes and the comment
// above each recipe (`apply_recipes.py` writes it). The types are in `CameraLookTypes.swift`.
extension CameraStyle {
    nonisolated var look: CameraLook {
        switch self {
        case .film:
            // D Classic: refitted 13 October 2026 on its 7 pictures (--reg 8 --hue-reg 2: 2.1, 2.1, 2.6, 2.2, 2.0, 3.4, 1.7); the table (prior 0.1, smooth 0.2, skin 3) 1.6, 1.3, 1.8, 2.0, 1.4, 2.2, 1.2; held-out median gap +0.41.
            CameraLook(
                blurRadius: 0.18, vignette: 0.088, stamp: .dateSegments,
                color: ColorStage(
                    matrix: [[1.0092, -0.0098, 0.0606, -0.0115], [-0.0180, 1.0039, 0.0748, -0.0160], [-0.0761, -0.0115, 0.9938, -0.0040]],
                    curves: [[0.0756, 0.0771, 0.2485, 0.5143, 0.7590, 0.9207], [0.0850, 0.1041, 0.2974, 0.5435, 0.7510, 0.9055],
                             [0.0790, 0.1086, 0.3156, 0.6009, 0.8189, 0.9555]],
                    hue: HueTerms(
                        shift: [-0.0501, -0.0407, -0.0125, -0.0179, -0.0620, -0.0698, -0.0340, 0.0064],
                        saturation: [0.9662, 0.9652, 0.9539, 0.9048, 0.9098, 0.9217, 0.8562, 0.9411],
                        lightness: [0.9956, 1.0025, 1.0145, 1.0245, 1.0007, 0.9929, 0.9827, 0.9882]
                    )
                ),
                colorCube: "film",
                halation: Halation(threshold: 0.5, radius: 0.75, amount: 0.15, tintHex: 0xE0F0FF),
                filmGrain: FilmGrain(size: 0.8, amount: 0.048, color: 0.2),
                frame: .fullFrame
            )
        case .disposable:
            CameraLook(
                filters: [.contrast(1.22), .saturate(1.35), .sepia(0.16), .brightness(1.13)],
                blurRadius: 0, tintHex: 0xFFCF5A, tint: 0.18, flash: 0.7, fade: 0, chroma: 0, scan: 0,
                vignette: 0.4, grain: 0.42, stamp: .date
            )
        case .instant:
            // Inst C: refitted 13 October 2026 on its 7 pictures (--reg 8 --hue-reg 6: 3.6, 4.1, 3.6, 2.2, 2.5, 5.0, 3.3); the table (prior 0.3, smooth 2, skin 3) 2.5, 3.0, 2.2, 1.6, 1.2, 3.8, 2.1; held-out median gap +0.47.
            CameraLook(
                blurRadius: 0.34, vignette: 0.341,
                color: ColorStage(
                    matrix: [[1.0069, 0.0045, 0.0433, 0.0071], [0.1270, 0.9197, 0.1544, -0.0364], [0.0256, 0.1692, 0.9621, -0.0082]],
                    curves: [[0.1100, 0.1323, 0.2165, 0.4296, 0.7560, 0.9158], [0.0639, 0.1072, 0.2373, 0.4499, 0.7203, 0.8911],
                             [0.0070, 0.0625, 0.2080, 0.4631, 0.7667, 0.9108]],
                    hue: HueTerms(
                        shift: [-0.0164, -0.0113, -0.0065, -0.0148, -0.0093, 0.0067, 0.0256, -0.0080],
                        saturation: [0.9980, 0.9964, 0.9935, 0.9879, 0.9871, 0.9838, 0.9722, 0.9942],
                        lightness: [1.0009, 1.0014, 1.0033, 1.0045, 0.9993, 0.9959, 0.9928, 0.9999]
                    )
                ),
                colorCube: "inst",
                halation: Halation(threshold: 0.4, radius: 0.75, amount: 0.25, tintHex: 0xFFFFFF),
                filmGrain: FilmGrain(size: 0.8, amount: 0.084, color: 0.22),
                frame: .instantPrint
            )
        case .digicam:
            CameraLook(
                filters: [.contrast(1.16), .saturate(0.86), .brightness(1.06)],
                blurRadius: 0, tintHex: 0x3D7DFF, tint: 0.28, flash: 0.15, fade: 0, chroma: 0, scan: 0,
                vignette: 0.08, grain: 0.08, stamp: .date
            )
        case .camcorder:
            CameraLook(
                filters: [.saturate(1.5), .contrast(0.9), .brightness(1.06)],
                blurRadius: 0.6, tintHex: 0x20D0C0, tint: 0.14, flash: 0, fade: 0.05, chroma: 0.5, scan: 0.4,
                vignette: 0.32, grain: 0.22, stamp: .vhs
            )

        // Batch 1: fitted from the reference pairs in `ref/pairs`, in sRGB (the first fits read the pictures'
        // Display P3 values as sRGB, which dulled every saturated colour on a phone). In brackets: the median
        // ΔE2000 of the fit on each picture, over 4×4 boxes; with texture averaged out (a 16 px blur) the colour
        // mapping itself is 1.2 to 2.7 on every picture. Halation is fitted by `tools/halation.py` on the same
        // pairs, grain by `tools/grain.py` (amplitude and how coloured it is).

        case .negative:
            // 135 NE: refitted 13 October 2026 on its 6 pictures (--reg 3: 3.8, 4.4, 2.3, 2.6, 6.4, 3.3); the table (prior 2.4, smooth 16, skin 3) 3.4, 3.7, 2.2, 2.4, 6.4, 3.3; held-out median gap +0.46.
            CameraLook(
                blurRadius: 0.00, vignette: 0.505,
                color: ColorStage(
                    matrix: [[1.0439, -0.0805, -0.0313, 0.0318], [0.1088, 0.9521, -0.0182, -0.0085], [0.0562, -0.0313, 0.9999, 0.0196]],
                    curves: [[-0.0043, 0.0679, 0.2203, 0.4515, 0.7533, 0.9938], [0.0464, 0.1314, 0.2571, 0.4355, 0.6667, 0.8995],
                             [0.0061, 0.0993, 0.2220, 0.4164, 0.6405, 0.8593]],
                    hue: HueTerms(
                        shift: [0.0345, 0.0555, 0.0629, 0.1299, 0.0585, 0.0330, 0.0753, 0.0013],
                        saturation: [1.0235, 1.0003, 0.9812, 0.9203, 0.9479, 1.0502, 1.0436, 1.0644],
                        lightness: [1.0031, 0.9925, 0.9978, 0.9809, 0.9359, 0.9470, 0.9106, 1.0198]
                    )
                ),
                colorCube: "negative",
                halation: Halation(threshold: 0.5, radius: 1.5, amount: 0.4, tintHex: 0xFFFFFF),
                filmGrain: FilmGrain(size: 0.8, amount: 0.065, color: 0.15),
                frame: .filmStrip
            )

        case .plastic35:
            // CPM35: refitted 13 October 2026 on its 6 pictures (--reg 3: 2.7, 2.5, 3.6, 3.1, 3.7, 2.6); the table (prior 0.1, smooth 0.2, skin 3) 2.1, 2.1, 3.3, 2.5, 2.9, 1.8; held-out median gap +0.44.
            CameraLook(
                blurRadius: 0.16, vignette: 0.243, stamp: .dateMatrix,
                color: ColorStage(
                    matrix: [[1.0125, 0.0183, 0.0255, -0.0213], [-0.0345, 0.9823, 0.1178, -0.0269], [-0.0530, -0.0462, 1.0479, 0.0062]],
                    curves: [[0.1022, 0.1349, 0.2586, 0.4484, 0.7142, 0.9654], [0.1535, 0.2005, 0.3230, 0.5007, 0.7505, 0.9689],
                             [0.1444, 0.1926, 0.3075, 0.5171, 0.7991, 1.0073]],
                    hue: HueTerms(
                        shift: [-0.0309, -0.0770, -0.0507, -0.1360, -0.0221, 0.0395, 0.0159, 0.0333],
                        saturation: [1.0027, 0.9632, 0.9560, 0.9173, 0.8503, 1.0361, 0.9648, 1.0553],
                        lightness: [1.0054, 1.0016, 1.0082, 1.0101, 1.0105, 1.0214, 0.9494, 0.9951]
                    )
                ),
                colorCube: "plastic35",
                halation: Halation(threshold: 0.4, radius: 4, amount: 0.15, tintHex: 0xFFFFFF),
                filmGrain: FilmGrain(size: 0.45, amount: 0.109, color: 0.15),
                frame: .fullFrame
            )

        case .slide:
            // D Slide: refitted 13 October 2026 on its 6 pictures (--reg 3: 2.8, 2.6, 2.1, 2.0, 5.2, 2.4); the table (prior 1.2, smooth 8, skin 3) 2.9, 2.3, 1.5, 1.5, 5.6, 1.7; held-out median gap +0.47.
            CameraLook(
                blurRadius: 0.00, vignette: 0.265,
                color: ColorStage(
                    matrix: [[1.0078, 0.0543, 0.0818, -0.0412], [0.0741, 0.9388, 0.1156, -0.0449], [-0.0450, 0.1420, 0.9650, 0.0229]],
                    curves: [[0.0706, 0.0787, 0.2063, 0.4256, 0.6916, 0.9149], [0.0689, 0.0834, 0.2187, 0.4390, 0.7330, 0.9514],
                             [0.0602, 0.0660, 0.1480, 0.3739, 0.7094, 0.9199]],
                    hue: HueTerms(
                        shift: [-0.1242, -0.0666, -0.0255, 0.0279, 0.0377, -0.0459, 0.0314, 0.0553],
                        saturation: [0.8455, 0.9218, 0.8843, 0.7794, 0.7282, 0.7022, 0.6282, 0.8837],
                        lightness: [1.0248, 0.9943, 0.9983, 1.0000, 0.9951, 1.0021, 1.0135, 1.0539]
                    )
                ),
                colorCube: "slide",
                halation: Halation(threshold: 0.4, radius: 1.5, amount: 0.25, tintHex: 0xE0F0FF),
                filmGrain: FilmGrain(size: 0.9, amount: 0.03, color: 0.2),
                frame: .slideMount
            )

        case .mediumFormat:
            // S 67: refitted 13 October 2026 on its 6 pictures (--reg 3: 2.8, 3.7, 1.8, 1.8, 5.2, 2.1); the table (prior 2.4, smooth 16, skin 3) 2.5, 3.1, 1.5, 1.4, 4.8, 2.0; held-out median gap +0.38.
            CameraLook(
                blurRadius: 0.00, vignette: 0.332,
                color: ColorStage(
                    matrix: [[1.0333, -0.1382, 0.0203, 0.0459], [-0.0825, 0.9878, 0.1166, -0.0203], [-0.0466, 0.1341, 0.9672, -0.0249]],
                    curves: [[0.0050, 0.0289, 0.1706, 0.4121, 0.6929, 0.9369], [0.0245, 0.0863, 0.2327, 0.4302, 0.6569, 0.8935],
                             [0.0331, 0.0976, 0.2351, 0.4520, 0.6786, 0.8770]],
                    hue: HueTerms(
                        shift: [-0.2068, -0.0864, -0.0342, 0.0161, 0.0933, 0.0215, 0.0387, -0.1175],
                        saturation: [1.1091, 1.0564, 1.0116, 1.0047, 1.0484, 0.9501, 0.9016, 1.0749],
                        lightness: [1.0468, 1.0176, 1.0020, 1.0349, 1.0792, 1.0067, 0.9748, 1.0558]
                    )
                ),
                colorCube: "mediumFormat",
                halation: Halation(threshold: 0.5, radius: 1.5, amount: 0.25, tintHex: 0xFFFFFF),
                filmGrain: FilmGrain(size: 0.7, amount: 0.04, color: 0.25),
                frame: .mediumFormat
            )

        case .tlr:
            // S Classic: refitted 13 October 2026 on its 6 pictures (--reg 3: 2.4, 3.0, 1.5, 1.2, 3.8, 2.3); the table (prior 1.2, smooth 8, skin 3) 2.0, 2.6, 1.2, 1.1, 3.5, 1.8; held-out median gap +0.38.
            CameraLook(
                blurRadius: 0.05, vignette: 0.338,
                color: ColorStage(
                    matrix: [[1.0245, -0.1193, -0.0346, -0.0002], [0.0867, 0.9257, 0.0195, -0.0196], [0.1046, -0.1254, 0.9775, -0.0050]],
                    curves: [[0.0331, 0.0579, 0.2159, 0.4647, 0.7964, 1.0948], [0.0314, 0.0803, 0.2122, 0.3892, 0.6397, 0.9117],
                             [0.0238, 0.0722, 0.2016, 0.4036, 0.6726, 0.9215]],
                    hue: HueTerms(
                        shift: [-0.0158, 0.0351, 0.0714, 0.0449, 0.0012, -0.0502, 0.0355, -0.0465],
                        saturation: [1.0916, 1.0444, 0.9474, 0.8885, 0.9253, 1.0671, 1.1422, 1.2047],
                        lightness: [0.9786, 0.9797, 0.9640, 0.9252, 0.8902, 0.9366, 0.9538, 0.9750]
                    )
                ),
                colorCube: "tlr",
                halation: Halation(threshold: 0.4, radius: 1.5, amount: 0.15, tintHex: 0xFFFFFF),
                filmGrain: FilmGrain(size: 0.8, amount: 0.037, color: 0.2),
                frame: .square
            )

        // Batch 2: fitted from the reference app's exports (`ref/pairs/<id>`, `<id>-1`, `<id>-2`), then refitted in
        // the refinement round on all seven pictures like batch 1.

        case .compactPro:
            // CT2F: refitted 13 October 2026 on its 7 pictures (--reg 8 --hue-reg 6: 2.9, 3.6, 4.0, 2.5, 2.2, 7.5, 1.9); the table (prior 0.1, smooth 0.2, skin 3) 2.3, 2.5, 3.0, 1.9, 1.6, 4.5, 1.5; held-out median gap +0.46.
            CameraLook(
                blurRadius: 0.06, vignette: 0.217, stamp: .dateSegments,
                color: ColorStage(
                    matrix: [[0.9821, 0.0133, 0.0790, -0.0319], [0.0166, 1.0179, 0.0248, -0.0302], [-0.0613, 0.0758, 0.9916, -0.0201]],
                    curves: [[0.0976, 0.1267, 0.3681, 0.6320, 0.8005, 0.9478], [0.0942, 0.1404, 0.4164, 0.6328, 0.7816, 0.9031],
                             [0.0852, 0.1233, 0.4197, 0.6887, 0.8616, 0.9695]],
                    hue: HueTerms(
                        shift: [0.0014, -0.0012, -0.0152, -0.0556, -0.0513, -0.0170, 0.0175, 0.0132],
                        saturation: [0.9913, 0.9957, 0.9932, 0.9887, 0.9867, 0.9861, 0.9628, 0.9836],
                        lightness: [1.0006, 1.0039, 1.0120, 1.0097, 1.0043, 1.0034, 0.9996, 0.9998]
                    )
                ),
                colorCube: "compactPro",
                halation: Halation(threshold: 0.4, radius: 1.5, amount: 0.25, tintHex: 0xFFFFFF),
                filmGrain: FilmGrain(size: 0.8, amount: 0.054, color: 0.28),
                frame: .fullFrame
            )

        case .classicSLR:
            // Classic U: refitted 13 October 2026 on its 7 pictures (--reg 8 --hue-reg 6: 3.7, 3.4, 4.3, 2.4, 3.1, 5.3, 4.0); the table (prior 0.1, smooth 0.2, skin 3) 2.5, 2.6, 2.9, 1.9, 1.8, 3.4, 2.2; held-out median gap +0.42.
            CameraLook(
                blurRadius: 0.10, vignette: 0.152, stamp: .dateDots,
                color: ColorStage(
                    matrix: [[1.0022, -0.0473, -0.0048, -0.0015], [0.0273, 0.9181, 0.1839, -0.0181], [-0.0808, 0.0974, 1.0064, 0.0189]],
                    curves: [[0.0846, 0.1138, 0.2727, 0.5178, 0.8087, 0.9650], [0.0460, 0.0916, 0.2585, 0.4818, 0.7251, 0.9225],
                             [0.0307, 0.0459, 0.2157, 0.4948, 0.7932, 0.9470]],
                    hue: HueTerms(
                        shift: [-0.0220, -0.0148, -0.0052, -0.0195, -0.0179, -0.0012, 0.0191, -0.0017],
                        saturation: [1.0014, 0.9972, 0.9903, 0.9843, 0.9889, 0.9915, 0.9874, 1.0039],
                        lightness: [0.9973, 0.9982, 0.9981, 0.9947, 0.9946, 0.9942, 0.9916, 0.9940]
                    )
                ),
                colorCube: "classicSLR",
                halation: Halation(threshold: 0.4, radius: 6, amount: 0.15, tintHex: 0xE0F0FF),
                filmGrain: FilmGrain(size: 0.8, amount: 0.128, color: 0.15),
                frame: .fullFrame
            )

        case .instSquare:
            // Inst SQC: refitted 13 October 2026 on its 7 pictures (--reg 8 --hue-reg 6: 3.3, 3.1, 3.9, 2.5, 2.3, 5.8, 2.8); the table (prior 0.3, smooth 2, skin 3) 2.0, 1.7, 2.4, 1.6, 1.3, 4.8, 1.3; held-out median gap +0.38.
            CameraLook(
                blurRadius: 0.36, vignette: 0.194,
                color: ColorStage(
                    matrix: [[1.0040, 0.0077, 0.0479, 0.0081], [0.1256, 0.9195, 0.1622, -0.0320], [0.0108, 0.1650, 0.9700, -0.0015]],
                    curves: [[0.1034, 0.1354, 0.2297, 0.4529, 0.7647, 0.9046], [0.0597, 0.1148, 0.2487, 0.4651, 0.7232, 0.8805],
                             [-0.0056, 0.0682, 0.2239, 0.4814, 0.7723, 0.8961]],
                    hue: HueTerms(
                        shift: [-0.0114, -0.0079, -0.0055, -0.0130, -0.0107, 0.0056, 0.0225, -0.0068],
                        saturation: [0.9994, 0.9973, 0.9937, 0.9862, 0.9848, 0.9814, 0.9715, 0.9968],
                        lightness: [1.0000, 1.0008, 1.0022, 1.0020, 0.9972, 0.9932, 0.9895, 0.9978]
                    )
                ),
                colorCube: "instSquare",
                halation: Halation(threshold: 0.4, radius: 1.5, amount: 0.4, tintHex: 0xFFFFFF),
                filmGrain: FilmGrain(size: 0.8, amount: 0.081, color: 0.22),
                frame: .squarePrint
            )
        }
    }
}
