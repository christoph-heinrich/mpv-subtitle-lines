# mpv-subtitle-lines
List and search subtitle lines of the selected subtitle track, that mpv has already loaded internally.  
No need for external tools (e.g. ffmpeg), no need to reload the same subtitles mpv has already loaded.

Select a line to seek to it's start time.

![screenshot](preview.jpg)

Requires [uosc](https://github.com/tomasklaen/uosc) 5.0.0 or newer.

## Installation
1. Save the `subtitle-lines.lua` into your [scripts directory](https://mpv.io/manual/stable/#script-location)
2. Set key bindings in [`input.conf`](https://mpv.io/manual/stable/#input-conf)
    ```
    Ctrl+f script-binding subtitle_lines/list_subtitles
    ```

## Recommended usage

When turning on subtitles, mpv loads subtitles from the current playback time forward. Therefore it is recommended to always have subtitles selected.  
For example here is a `mpv.conf` configuration for English and German, with a preference for English.
```ini
slang=eng,ger
subs-with-matching-audio=yes
ytdl-raw-options-append=sub-langs=en.*,de.*
```

### "But I don't want to always see subtitles."

Then hide them when the audio language is a language you understand using a [conditional auto profile](https://mpv.io/manual/master/#conditional-auto-profiles).  
For example to hide subtitles when the audio language is English or German and the subtitles are not forced:
```ini
[hide-subtitles]
profile-cond=not get('current-tracks/sub/forced') and (function() local hide_for = {'en','eng','de','deu','ger'} local a = get('current-tracks/audio/lang') a = a and a:match('^%w+') for _, hl in ipairs(hide_for) do if a == hl then return true end end end)()
profile-restore=copy
sub-visibility=no
```

Unfortunately the audio track doesn't always have a language set, in which case the subtitles won't be hidden with this. However that situation seems to be rare in practice.

## Current limitations

* Only lists subtitles that mpv has loaded internally.
* After seeking mpv only provides the current subtitle line and requires some (short) playback for the other lines to become available.
* Acquiring subtitle lines isn't 100% accurate.

Resolving those requires changes to mpv or external tools.