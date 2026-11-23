<script setup lang="ts">
/**
 * A phone around whatever is in its slot: the classic home button phone, so it reads as a
 * phone at a glance and not as a panel. Landscape (how Roblox games are played) unless
 * `portrait`. The screen is 16:9, the shape of Studio's phone emulator, unless `aspect`
 * (a CSS aspect-ratio, width / height as held) gives another.
 */
const props = defineProps<{
  portrait?: boolean
  aspect?: string
}>()
</script>

<template>
  <div
    class="phone"
    :class="props.portrait ? 'phone-portrait' : 'phone-landscape'"
  >
    <div class="phone-body">
      <span
        v-for="n in 3"
        :key="n"
        aria-hidden="true"
        :class="['phone-key', `phone-key-${n}`]"
      />
      <span
        aria-hidden="true"
        class="phone-key phone-key-top"
      />
      <span
        aria-hidden="true"
        class="phone-speaker"
      />
      <span
        aria-hidden="true"
        class="phone-camera"
      />
      <span
        aria-hidden="true"
        class="phone-home"
      />
      <div class="phone-screen">
        <div
          class="phone-display"
          :style="props.aspect ? { aspectRatio: props.aspect } : undefined"
        >
          <slot />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Every size is a share of the phone's length (container units), so it looks the same at any size. */
.phone {
  container-type: inline-size;
  width: 100%;
  margin-inline: auto;
}
.phone-landscape {
  max-width: 40rem;
}
.phone-portrait {
  max-width: 19rem;
}

.phone-body {
  position: relative;
  background: #19191c;
  box-shadow:
    inset 0 0 0 0.15cqw #2c2c31,
    0 2cqw 5cqw -1.5cqw rgb(0 0 0 / 0.5);
}
.phone-landscape .phone-body {
  border-radius: 12cqw;
  padding: 2.1cqw 10.8cqw 1.9cqw 11.7cqw;
}
.phone-portrait .phone-body {
  border-radius: 24cqw;
  padding: 23.4cqw 3.8cqw 21.6cqw;
}

/* The screen: black glass, with what the slot shows inside a black edge, as on a real display. */
.phone-screen {
  background: #000;
  border-radius: 0.4cqw;
  padding: 1.1cqw;
  box-shadow: 0 0 0 0.12cqw #0b0b0d;
}
.phone-display {
  position: relative;
  overflow: hidden;
  background: #000;
  aspect-ratio: 16 / 9;
}
.phone-portrait .phone-display {
  aspect-ratio: 9 / 16;
}
.phone-display > :deep(img) {
  display: block;
  width: 100%;
  height: 100%;
  margin: 0;
  border: 0;
  border-radius: 0;
  object-fit: cover;
}

/* The speaker slot and the camera, on the side away from the home button. */
.phone-speaker,
.phone-camera,
.phone-home,
.phone-key {
  position: absolute;
}
.phone-speaker {
  background: #2e2e33;
  border-radius: 999px;
}
.phone-camera {
  background: #2e2e33;
  border-radius: 999px;
}
.phone-home {
  background: #222226;
  border-radius: 999px;
  box-shadow: inset 0 0 0 0.12cqw #2e2e33;
}
.phone-landscape .phone-speaker { left: 6.1cqw; top: 50%; width: 0.75cqw; height: 6.6cqw; transform: translateY(-50%); }
.phone-landscape .phone-camera { left: 5.9cqw; top: calc(50% + 6.4cqw); width: 1.25cqw; height: 1.25cqw; }
.phone-landscape .phone-home { right: 3cqw; top: 50%; width: 6.6cqw; height: 6.6cqw; transform: translateY(-50%); }
.phone-portrait .phone-speaker { top: 11.5cqw; left: 50%; width: 13cqw; height: 1.5cqw; transform: translateX(-50%); }
.phone-portrait .phone-camera { top: 11.2cqw; left: calc(50% - 13cqw); width: 2.4cqw; height: 2.4cqw; }
.phone-portrait .phone-home { bottom: 5.8cqw; left: 50%; width: 13cqw; height: 13cqw; transform: translateX(-50%); }

/* The side keys: thin bars just outside the body's edges. */
.phone-key {
  background: #45454c;
  border-radius: 0.2cqw;
}
.phone-landscape .phone-key { height: 0.3cqw; bottom: -0.35cqw; }
.phone-landscape .phone-key-1 { left: 13cqw; width: 4cqw; }
.phone-landscape .phone-key-2 { left: 21.2cqw; width: 7.5cqw; }
.phone-landscape .phone-key-3 { left: 30.4cqw; width: 7.5cqw; }
.phone-landscape .phone-key-top { top: -0.35cqw; bottom: auto; left: 21.2cqw; width: 7.5cqw; }
.phone-portrait .phone-key { width: 0.6cqw; left: -0.7cqw; }
.phone-portrait .phone-key-1 { top: 17cqw; height: 6cqw; }
.phone-portrait .phone-key-2 { top: 28cqw; height: 11cqw; }
.phone-portrait .phone-key-3 { top: 42cqw; height: 11cqw; }
.phone-portrait .phone-key-top { left: auto; right: -0.7cqw; top: 28cqw; height: 11cqw; }
</style>
