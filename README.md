# Local AI Stack — Mac Mini M4 (24GB)

A self-updating, self-hosted AI stack: private chat (text + image generation),
accessible from a web UI and from iOS/Android, running entirely on your
Mac Mini.

**Components**

| Component   | Role                                  | Port  |
|-------------|---------------------------------------|-------|
| Ollama      | Runs the LLM (chat + story generation) | 11434 |
| Open WebUI  | Web UI + OpenAI-compatible API for mobile apps | 3000 |
| ComfyUI     | Image generation backend (FLUX.1)     | 8188  |

**Default model:** `mannix/llama3.1-8b-abliterated:q5_K_M` (~5.7GB) —
chosen to leave plenty of RAM headroom on a 24GB machine for context,
Open WebUI, and ComfyUI running simultaneously.

---

## 1. One-time setup

1. Copy this whole folder (`ai-stack-setup/`) onto the Mac Mini, e.g. to
   `~/Downloads/ai-stack-setup/`.
2. Open Terminal and run:

   ```bash
   cd ~/Downloads/ai-stack-setup
   chmod +x install.sh
   bash install.sh
   ```

3. **If this is the very first run and OrbStack wasn't installed yet**,
   the script will install it, open it, and then exit. OrbStack needs
   to complete its one-time first-launch setup (grant permissions,
   etc.) — once that's done, **just run `bash install.sh` again** and
   it will pick up where it left off.

4. When the script finishes, you'll see URLs for Open WebUI, ComfyUI,
   and Ollama. At this point:
   - The LLM is downloaded and running.
   - Open WebUI is running and configured to talk to Ollama.
   - ComfyUI is running but **has no image model yet** (see Step 4 below).
   - Auto-update is installed and will run on every reboot.

---

## 2. First login to Open WebUI

1. Visit **http://localhost:3000** (or `http://<mac-mini-ip>:3000` from
   another device on your network).
2. Create your admin account on first visit (this is local-only — it's
   not sent anywhere).
3. In the model dropdown, you should see
   `mannix/llama3.1-8b-abliterated:q5_K_M`. Send a test message to
   confirm chat works.

---

## 3. Story generation

No extra setup needed — the chat model handles long-form creative
writing directly. For best results with longer stories, in Open WebUI
go to **Settings → Models → (your model) → Advanced Params** and
increase the **context length** (`num_ctx`) — e.g. 8192 or 16384.
Higher context uses more RAM, so increase gradually and watch memory
in Activity Monitor.

---

## 4. Image generation setup (ComfyUI + FLUX.1-schnell)

This part is manual because the model files are large (~20GB combined)
and gated behind a Hugging Face account.

1. Create a free account at https://huggingface.co if you don't have
   one, and accept the FLUX.1-schnell license at:
   https://huggingface.co/black-forest-labs/FLUX.1-schnell

2. Run the download script — it will prompt once for a Hugging Face
   access token (read access is enough, from
   https://huggingface.co/settings/tokens), cache it locally, and use
   `wget` to download + place all four required files automatically:

   ```bash
   cd ~/ai-stack
   chmod +x download-flux-models.sh
   bash download-flux-models.sh
   ```

   This downloads (~20GB total):

   | File | Destination |
   |------|-------------|
   | `flux1-schnell.safetensors` | `models/checkpoints/` (and symlinked into `models/unet/`) |
   | `ae.safetensors` | `models/vae/` |
   | `clip_l.safetensors` | `models/clip/` |
   | `t5xxl_fp8_e4m3fn.safetensors` | `models/clip/` (fp8 variant — recommended for 24GB systems) |

   The script restarts ComfyUI automatically when done.
   and check that the checkpoint/VAE/CLIP dropdowns are populated.

5. **Connect ComfyUI to Open WebUI:**

   - Open **http://localhost:8188** (the ComfyUI web interface,
     running natively on the Mac Mini).
   - Click the **gear/settings icon** near the top of the toolbar
     (next to "Queue Size").
   - In the settings panel, find **"Enable Dev mode options (API
     save, etc.)"** — it's typically under the "Comfy" category, or
     use the settings search box and type "dev" to jump straight to
     it.
   - Toggle it **on** and close the settings panel.
   - Build (or load) a basic FLUX text-to-image workflow on the
     canvas. To make this easy, this repo includes a ready-made
     workflow: **`flux-schnell-workflow.json`**. To use it:
     - Drag `flux-schnell-workflow.json` from Finder directly onto
       the ComfyUI canvas in your browser (or use the menu →
       **Workflow → Open** and select the file).
     - This loads a pre-wired graph: `UNETLoader` → `DualCLIPLoader`
       + `VAELoader` → `CLIPTextEncode` (positive/negative) →
       `EmptyLatentImage` → `KSampler` → `VAEDecode` → `SaveImage`,
       already pointing at the exact filenames downloaded in Step 4
       (`flux1-schnell.safetensors`, `clip_l.safetensors`,
       `t5xxl_fp8_e4m3fn.safetensors`, `ae.safetensors`), with
       schnell-appropriate settings (4 steps, CFG 1.0).
     - Click **Queue Prompt** once to confirm it generates an image
       successfully before exporting it for Open WebUI.
   - With Dev Mode on, open the workflow save menu — you'll now see
     an extra option: **"Save (API Format)"**. Click it (*not* the
     regular "Save") and download the resulting JSON file.
   - In Open WebUI, go to **Admin Panel → Settings → Images**:
     - Image Generation Engine: `ComfyUI`
     - ComfyUI Base URL: `http://host.docker.internal:8188`
     - Upload the workflow JSON you just exported.
     - Map the **ComfyUI Workflow Nodes**. Each field has a *Key*
       (the input parameter name) and a *Node ID* (which node in the
       workflow contains it). For `flux-schnell-workflow.json`, the
       node IDs are preserved as 1-9.

       **Note:** depending on your Open WebUI version, you may only
       see a subset of these fields (commonly just Model, Prompt,
       Width, Height, Steps, and Seed — without Negative Prompt, CFG
       Scale, Sampler, or Scheduler). That's fine. Map whichever
       fields are present:

       | Field | Key | Node ID(s) | If field is missing |
       |---|---|---|---|
       | Model | `unet_name` | `1` | — |
       | Prompt | `text` | `4` | — |
       | Width | `width` | `6` | uses workflow default (1024) |
       | Height | `height` | `6` | uses workflow default (1024) |
       | Steps | `steps` | `7` | uses workflow default (4) |
       | Seed | `seed` | `7` | randomized per workflow setting |
       | Negative Prompt | `text` | `5` | uses workflow default ("") |
       | CFG Scale | `cfg` | `7` | uses workflow default (1.0) |
       | Sampler | `sampler_name` | `7` | uses workflow default (`euler`) |
       | Scheduler | `scheduler` | `7` | uses workflow default (`simple`) |

       The workflow's hardcoded defaults are already correct for
       FLUX.1-schnell, so unmapped fields aren't a problem — Model
       and Prompt are the only two that are essential.

       > **Important:** Open WebUI's default Key for "Model" is
       > `ckpt_name` (for `CheckpointLoaderSimple`). Since this
       > workflow uses `UNETLoader`, you must change that Key to
       > `unet_name`, or model selection won't work.
   - Save. You should now see an image-generation option in the chat
     interface.

> If you ever get "Invalid workflow / JSON parse error," it's almost
> always because the workflow was exported with the regular Save
> button instead of **Save (API Format)** — re-export it.

---

## 5. Mobile access (iOS / Android)

### Option A — Open WebUI as a PWA (simplest, no extra app)
1. On your phone, open Safari/Chrome and go to
   `http://<mac-mini-ip>:3000`.
2. Use "Add to Home Screen" — it behaves like a native app, supports
   streaming chat, and can trigger image generation through the same
   ComfyUI integration.
3. For access **away from home**, see Section 7 (Tailscale) — don't
   port-forward 3000 directly to the internet.

### Option B — LM Mini (more native feel, built-in image gen UI)
1. Install **LM Mini** from the App Store / Play Store.
2. Point it at your Mac Mini's Ollama endpoint:
   `http://<mac-mini-ip>:11434` (or the Tailscale address — see
   Section 7).
3. In LM Mini's image generation settings, switch the backend to
   ComfyUI and point it at `http://<mac-mini-ip>:8188`, then select
   the same exported workflow JSON.

---

## 6. Updating everything

Updates run **automatically every time the Mac Mini reboots** (via
launchd). To update on demand without rebooting:

```bash
~/ai-stack/update-ai-stack.sh
```

This single command:
- Updates Ollama itself (via Homebrew) and restarts it
- Re-pulls the LLM (picks up newer quantizations/versions if you
  change the tag in the script)
- Pulls the latest Open WebUI Docker image and recreates the container
- Pulls the latest ComfyUI source + custom nodes and updates their
  Python dependencies
- Restarts ComfyUI to apply changes
- Logs everything to `~/ai-stack/logs/update-YYYY-MM-DD.log`

**To switch to a different/better LLM later:** edit the `MODEL=`
line near the top of `~/ai-stack/update-ai-stack.sh` and the
`DEFAULT_MODELS=` line in `~/ai-stack/docker-compose.yml`, then run
the update script once.

---

## 7. Remote access while away from home (recommended: Tailscale)

To use the iOS/Android apps when you're not on your home network
without exposing anything to the public internet:

```bash
brew install --cask tailscale
```

1. Open Tailscale, sign in, and connect the Mac Mini.
2. Install the Tailscale app on your phone and sign in with the same
   account.
3. Use the Mac Mini's Tailscale IP (looks like `100.x.x.x`) instead of
   its LAN IP in the mobile app settings — it'll work from anywhere as
   if you were on your home network, fully encrypted, with no port
   forwarding.

---

## 8. Useful commands / troubleshooting

```bash
# Check Ollama is running and which models are installed
ollama list

# Tail ComfyUI logs
tail -f ~/ai-stack/logs/comfyui.err.log

# Restart Open WebUI only
cd ~/ai-stack && docker compose restart

# Restart ComfyUI only
launchctl kickstart -k gui/$(id -u)/com.ruberte.comfyui

# View last update run
cat ~/ai-stack/logs/update-$(date +%Y-%m-%d).log

# Check memory pressure (make sure model fits comfortably)
ollama ps
```

---

## 9. Uninstalling

To remove the stack, stop all services, and unload the launchd jobs,
but keep ComfyUI and your downloaded models in place (in case you
want to reinstall later):

```bash
cd ~/ai-stack
bash uninstall.sh
```

To remove **everything** — including Ollama itself, the LLM model,
ComfyUI, and all downloaded image models:

```bash
bash uninstall.sh --purge
```

> Note: `--purge` does not touch Homebrew, OrbStack/Docker, or
> Tailscale, since those are general-purpose tools you likely use
> for other things. Remove those separately with `brew uninstall
> --cask orbstack` / `brew uninstall --cask tailscale` if desired.

---

## 10. RAM budget reference (24GB system)

| Item | Approx. RAM |
|------|-------------|
| macOS overhead | ~4GB |
| LLM (8B Q5_K_M) + context | ~6-8GB |
| Open WebUI (Docker) | ~0.5-1GB |
| ComfyUI idle | ~1-2GB |
| ComfyUI during FLUX generation | ~8-10GB (transient) |

This leaves comfortable headroom for normal chat use; image generation
will be the heaviest moment and may briefly compete with the LLM if
both run at once. If you find this tight in practice, the update
script makes it trivial to drop to an even smaller LLM (e.g. a 7B
variant) without touching anything else.
