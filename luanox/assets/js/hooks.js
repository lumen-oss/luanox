import Typed from "typed.js";

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
}
