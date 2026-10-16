# Rover Dashboard

Live camera and lidar view from the rover.

1. **On the Jetson terminal**, run:
   ```
   cat ~/stream_url.txt
   ```
   Copy the link you get. It changes every time the Jetson starts.

2. **If using a hotspot**, open your browser settings and set secure DNS (DNS over HTTPS) to Cloudflare. On any other network, skip this step.

3. **Open the link.** The page connects automatically and shows the camera and lidar.
