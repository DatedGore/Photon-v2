Photon2.RegisterSchema({
    Name = "Default",
    Inputs = {
        ["Emergency.Warning"] = {
            { Label = "PRIMARY" },
            { Mode = "MODE1", Label = "STAGE 1" },
            { Mode = "MODE2", Label = "STAGE 2" },
            { Mode = "MODE3", Label = "STAGE 3" },
        },
        ["Emergency.Directional"] = {
            { Label = "ADVISOR" },
            { Mode = "LEFT", Label = "LEFT" },
            { Mode = "CENOUT", Label = "CTR/OUT" },
            { Mode = "RIGHT", Label = "RIGHT" }
        },
        ["Emergency.Marker"] = {
            { Label = "CRZ" },
            { Mode = "CRUISE", Label = "CRZ" }
        },
        ["Emergency.Auxiliary"] = {
            { Label = "AUX" },
            { Mode = "MODE1", Label = "RED" },
            { Mode = "MODE2", Label = "WHI" },
        },
        ["Emergency.Siren"] = {
            { Label = "SIREN" }
        }
    }
})