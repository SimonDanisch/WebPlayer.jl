module WebPlayer

using Colors, FixedPointNumbers, CSSUtil, WebIO, InteractNext

function copyframe!(frame, video, i)
    @inbounds for y = 1:size(frame, 2), x = 1:size(frame, 1)
        gray = video[x, y, i]
        frame[x, y] = RGB{N0f8}(gray, gray, gray)
    end
    frame
end

const set_play = js"""
function set_play(name, nvideos){
    var video;
    for(var i = 1; i <= nvideos; i++){
        video = document.getElementById(name + i);
        var button = document.getElementById("button");
        if(video.paused){
            video.play();
            button.textContent = " ⏸ ";
        }else{
            video.pause();
            button.textContent = " ▶ ";
        }
    }
    return video.currentTime / video.duration;
}
"""

const set_time = js"""
function set_time(name, nvideos, val, nframes){
    for(var i = 1; i <= nvideos; i++){
        var video = document.getElementById(name + i);
        var t = (val / nframes) * video.duration;
        video.currentTime = t;
    }
}
"""

function video_player(video, name = "test")
    dir = pwd()
    xdim, ydim, nframes = size(video)
    frame = Matrix{RGB{N0f8}}(xdim, ydim)
    path = joinpath(dir, "$name.mkv")
    io, process = open(`ffmpeg -loglevel panic -f rawvideo -pixel_format rgb24 -r 24 -s:v $(xdim)x$(ydim) -i pipe:0 -vf vflip -y $path`, "w")
    for i = 1:nframes
        copyframe!(frame, video, i)
        write(io, frame)
    end
    close(io)
    sleep(1)
    webmpath = joinpath(dir, "$(name).webm")
    run(`ffmpeg -loglevel quiet -i $(path) -c:v libvpx-vp9 -threads 16 -b:v 4000k -c:a libvorbis -threads 16 -vf scale=iw:ih -y $(webmpath)`)
    mp4path = joinpath(dir, "$(name).mp4")
    run(`ffmpeg -loglevel quiet -i $(path) -vcodec copy -acodec copy -y $(mp4path)`)

    dom"video"(
        dom"source"(attributes = Dict(
            :src => "files/$(name).webm", :type => "video/webm",
        )),
        dom"source"(attributes = Dict(
            :src => "files/$(name).mp4", :type => "video/mp4",
        )),
        id = name,
        attributes = Dict(:loop => "")
    )
end

package_dir() = joinpath(@__DIR__, "..")


function videobox(video, name)
    dom"div"(
        vbox(dom"div"(name), video),
        style = Dict(:outline => "1px solid #555", :width => "200px", :padding => "0.5em")
    )
end

function playvideo(videos::Vector{Array{T, 3}}, names = ["video $i" for i = 1:length(videos)]; frames_per_second = 24) where T <: AbstractFloat
    w = Widget()
    nvideos = length(videos)
    nframes = size(first(videos), 3)
    timestep = Observable(w, "timestep", 1)
    unique_name = first(names)
    button = dom"button"(
        " ▶ ",
        id = "button",
        events = Dict(
            "click" => @js function ()
                @var tnorm = $(set_play)($unique_name, $nvideos)
                $timestep[] = Math.round($nframes * tnorm)
            end),
    )
    s = dom"div"(
        InteractNext.slider(1:nframes, ob = timestep),
        style = Dict(:width => "400px", :padding => "0.5em")
    )

    onjs(timestep, @js function (val)
        $(set_time)($unique_name, $nvideos, val, $(nframes))
    end)
    video_players = w.(video_player.(videos, [string(unique_name, i) for i = 1:nvideos]))
    vbox(hbox(w(button), s), hbox(videobox.(video_players, names)...))
end

export playvideo

end # module
