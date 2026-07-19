-- GoblinPlates/Config.lua

local addonName, GP = ...

GP = GP or {}
_G.GoblinPlates = GP

function GP:InitializeConfig()

    GP.Config = {

        HealthBar = {
            Width = 124,
            Height = 12,
            Texture = "Interface\\Buttons\\WHITE8x8",
        },

        Frame = {
            Width = 128,
            Height = 32,
        },

        Name = {
            Font = "Fonts\\FRIZQT__.TTF",
            Size = 10,
            Outline = "OUTLINE",
        },

        Level = {
            Font = "Fonts\\FRIZQT__.TTF",
            Size = 10,
            Outline = "OUTLINE",
        },

        Border = {
            Size = 1,
        },

        Debug = true,

    }

end