using WebPlayer, FileIO, Images, Blink
using Base.Test, Colors
img = Float64.(Gray.(restrict(restrict(load(homedir() * "/Desktop/pliss.jpg")))))
video = Array{Float64, 3}(size(img)..., 100)
for f = 1:100
    for i = 1:size(img, 1), j = 1:size(img, 2)
        video[i, j, f] = img[i, j]
    end
end

videos = [video video];

x = WebPlayer.playvideo(videos, frames_per_second = 5)

w = Window()
body!(w, x)
tools(w)
