using WebPlayer
using Base.Test

video = [rand(150, 150, 3) for i = 1:100];
playvideo([video, video], ["Original movie","Rank 4 approximation"])
