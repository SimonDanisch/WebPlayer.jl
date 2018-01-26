module WebPlayer

using Colors, FixedPointNumbers, CSSUtil, WebIO, InteractNext

const set_play = js"""
function set_play(name, nvideos, fps, nframes, init){
    var video;
    var button = document.getElementById("button");
    var callback = function(){
        button.textContent = " ▶ ";
    };
    for(var i = 1; i <= nvideos; i++){
        video = document.getElementById(name + i);
        if(video.paused){
            video.play();
            if(!init){
                if(i == 1 && !init){
                    video.addEventListener('ended', callback);
                }
                var new_rate = (video.duration / nframes) / (1.0 / fps);
                video.playbackRate = new_rate;
            }
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


function video_player(video, name, width, style = Dict())
    mktempdir() do dir
        _xdim, _ydim, nframes = size(video)
        xdim = _xdim % 2 == 0 ? _xdim : _xdim + 1
        ydim = _ydim % 2 == 0 ? _ydim : _ydim + 1
        frame = fill(RGB{N0f8}(1, 1, 1), ydim, xdim)
        path = joinpath(dir, "$name.mkv")
        io, process = open(`ffmpeg -loglevel quiet -f rawvideo -pixel_format rgb24 -r 24 -s:v $(ydim)x$(xdim) -i pipe:0 -vf vflip -y $path`, "w")
        for i = 1:nframes
            for x in 1:_xdim, y in 1:_ydim
                g = video[(_xdim + 1) - x, y, i]
                frame[y, x] = RGB{N0f8}(g, g, g)
            end
            write(io, frame)
        end
        flush(io)
        close(io)
        wait(process)
        mp4path = joinpath(dir, "$(name).mp4")
        run(`ffmpeg -loglevel quiet -i $(path) -c:v libx264 -preset slow -crf 22 -pix_fmt yuv420p -c:a libvo_aacenc -b:a 128k -y $(mp4path)`)
        dom"video"(
            dom"source"(attributes = Dict(
                :src => string("data:video/mp4;base64,", base64encode(read(mp4path))),
                :type => "video/mp4",
            )),
            id = name,
            attributes = merge(Dict(:width => "100%"), style)
        )
    end
end

package_dir() = joinpath(@__DIR__, "..")


function videobox(video, name, width)
    dom"div"(
        vbox(dom"div"(name), dom"div"(video, style = Dict(:width => "$width"))),
        style = Dict(:outline => "1px solid #555", :padding => "0.5em")
    )
end


"""
    playvideo(
        videos::Vector{Array{T, 3}}, names = ["video i" for i = 1:length(videos)];
        frames_per_second = 24, width = 500
    )

Plays multiple videos side by side - names are optional and fall back to `video i`.
You can change the playback speed by passing your favorite frame rate to `frames_per_second = rate`.
One can also modify the width with the keyword argument `width = 500`.
"""
function playvideo(
        videos::Vector{Array{T, 3}},
        names = ["video $i" for i = 1:length(videos)];
        frames_per_second = 24, width = 500
    ) where T <: AbstractFloat

    w = Widget()
    nvideos = length(videos)
    nframes = size(first(videos), 3)
    timestep = Observable(w, "timestep", 1)
    initialized = Observable(w, "initialized", false)
    unique_name = first(names)

    button = dom"button"(
        " ▶ ",
        id = "button",
        events = Dict(
            "click" => @js function ()
                @var tnorm = $(set_play)(
                    $unique_name, $nvideos, $frames_per_second,
                    $nframes, $initialized[]
                )
                $initialized[] = false
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
    video_players = w.(video_player.(videos, [string(unique_name, i) for i = 1:nvideos], width))
    vbox(hbox(w(button), s), hbox(videobox.(video_players, names, width)...))
end

function playvideo(
        videos::Array{T, 3}, names = nothing;
        kw_args...
    ) where T <: AbstractFloat
    error("You gave a single video to video player: $(typeof(videos)). To play a video use a vector of videos, e.g.: [video1, video2]")
end


export playvideo

end # module
