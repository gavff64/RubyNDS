# Ohio State University's Byrd Polar and Climate Research Center public weather cam, may or may not be offline.
URL = "https://ipcam-1.byrd.osu.edu/mjpg/video.mjpg?resolution=256x192&compression=60&fps=5"

stream = HTTPS.get(URL, stream: true)
video = Draw.load(stream)

while System.main_loop?
  Draw.video(video, 0, 0, :top)
  System.vblank
end

Draw.stop
