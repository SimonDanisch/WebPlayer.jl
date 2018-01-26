using WebPlayer, FileIO, Images, Blink
using Base.Test, Colors
img = Float64.(Gray.(restrict(restrict(load(homedir() * "/Desktop/pliss.jpg")))))
video = Array{Float64, 3}(size(img)..., 100)
for f = 1:100
    r = rand() * 0.1
    for i = 1:size(img, 1), j = 1:size(img, 2)
        video[i, j, f] = clamp(img[i, j] + r, 0, 1)
    end
end

videos = [video, video];

x = WebPlayer.playvideo(videos, ["test", "test"], width = 200)
#
# w = Window()
# body!(w, x)
# tools(w)
