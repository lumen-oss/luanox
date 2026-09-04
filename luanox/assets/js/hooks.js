import Typed from "typed.js";

const CharacterCounter = {
  mounted() {
    const target = document.getElementById(this.el.dataset.counterTarget);
    if (!target) return;

    this.update = () => {
      target.textContent = `${this.el.value.length}/${this.el.dataset.counterMax}`;
      // If the input is higher than the max, we want to change the color of the counter to red. This is done with a CSS class.
      if (this.el.value.length > this.el.dataset.counterMax) {
        target.classList.add("text-error");
      } else {
        target.classList.remove("text-error");
      }
    };
    this.el.addEventListener("input", this.update);
    this.update();
  },
  updated() {
    this.update?.();
  },
  destroyed() {
    this.el.removeEventListener("input", this.update);
  },
};

const Typewriter = {
  mounted() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.el.textContent = "reliable";
      return;
    }
    this.typed = new Typed(this.el, {
      strings: ["modern", "fast", "reliable", "secure"],
      typeSpeed: 100,
      backSpeed: 50,
      loop: true,
    });
  },
  destroyed() {
    this.typed?.destroy();
  }
};

export default Hooks = {
  Typewriter: Typewriter,
  CharacterCounter: CharacterCounter,
}
