using WebPlayer
using Base.Test

video = [rand(150, 150, 100) for i = 1:2];
WebPlayer.playvideo(video, ["Original movie","Rank 4 approximation"])
