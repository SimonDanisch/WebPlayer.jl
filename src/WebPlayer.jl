module WebPlayer

using Colors, FixedPointNumbers, CSSUtil, WebIO, InteractNext

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
    return;
}
"""

function video_player(video, name = "test", width)
    dir = joinpath(pwd(), "assets")
    isdir(dir) || mkdir("assets")
    xdim, ydim, nframes = size(video)
    frame = Matrix{RGB{N0f8}}(xdim, ydim)
    path = joinpath(dir, "$name.mkv")
    io, process = open(`ffmpeg -loglevel quiet -f rawvideo -pixel_format rgb24 -r 24 -s:v $(xdim)x$(ydim) -i pipe:0 -vf vflip -y $path`, "w")
    for i = 1:nframes
        frame = RGB{N0f8}.(Gray.(view(video, :, size(video, 2):-1:1, i)))
        write(io, frame)
    end
    close(io)
    sleep(1)
    mp4path = joinpath(dir, "$(name).mp4")
    rm(mp4path, force = true)
    run(`ffmpeg -loglevel quiet -y -i $(path) -c:v libx264 -preset slow -crf 22 -pix_fmt yuv420p -c:a libvo_aacenc -b:a 128k -y $(mp4path)`)
    dom"video"(
        dom"source"(attributes = Dict(
            :src => "files/assets/$(name).mp4", :type => "video/mp4",
        )),
        id = name,
        attributes = Dict(:loop => "", :width = "100%")
    )
end

package_dir() = joinpath(@__DIR__, "..")


function videobox(video, name, width)
    dom"div"(
        vbox(dom"div"(name), video),
        style = Dict(:outline => "1px solid #555", :width => "$(width)px", :padding => "0.5em")
    )
end

function playvideo(videos::Vector{Array{T, 3}}, names = ["video $i" for i = 1:length(videos)]; frames_per_second = 24, width = 500) where T <: AbstractFloat
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
                $timestep[] = Math.round($(nframes) * tnorm)
                return
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
    vbox(hbox(w(button), s), hbox(videobox.(video_players, names, width)...))
end

export playvideo


end # module
