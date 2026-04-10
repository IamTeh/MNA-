-- =============================
--    MNA HUB V11.3 - KEY SYSTEM
-- =============================

local ValidKeys = {
    {key = "MNA-1111-AAAA", id = 8883763698},
    {key = "MNA-2222-BBBB", id = 9793848250},
}

-- Player ganti bagian ini dengan key mereka
local inputKey = "MASUKKAN_KEY_DISINI"

local player = game.Players.LocalPlayer
local allowed = false

for _, data in ipairs(ValidKeys) do
    if data.key == inputKey and data.id == player.UserId then
        allowed = true
        break
    end
end

if not allowed then
    error("\n\n❌ KEY TIDAK VALID atau ID TIDAK COCOK!\nHubungi owner untuk mendapatkan key.\n")
    return
end

print("✅ Key valid! Memuat MNA HUB V11.3...")
task.wait(1)

loadstring(game:HttpGet("https://raw.githubusercontent.com/IamTeh/MNA-/refs/heads/main/script.lua"))()
