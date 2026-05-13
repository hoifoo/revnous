import { Controller } from "@hotwired/stimulus"
import { Editor } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import { Placeholder } from "@tiptap/extensions"

export default class extends Controller {
  static targets = ["editor", "input"]

  connect() {
    const existingContent = this.inputTarget.value

    this.editor = new Editor({
      element: this.editorTarget,
      extensions: [
        StarterKit.configure({
          heading: { levels: [1, 2, 3, 4, 5, 6] }
        }),
        Placeholder.configure({
          placeholder: "Start writing your post..."
        })
      ],
      content: existingContent,
      onUpdate: ({ editor }) => {
        this.inputTarget.value = editor.getHTML()
      },
      onSelectionUpdate: ({ editor }) => {
        this.updateToolbarState(editor)
      },
      onTransaction: ({ editor }) => {
        this.updateToolbarState(editor)
      }
    })

    // Sync initial value so an empty form submission doesn't miss the field
    this.inputTarget.value = this.editor.getHTML()
  }

  disconnect() {
    if (this.editor) {
      this.editor.destroy()
      this.editor = null
    }
  }

  teardown() {
    if (this.editor) {
      this.editor.destroy()
      this.editor = null
    }
  }

  toggleBold() {
    this.editor.chain().focus().toggleBold().run()
  }

  setHeading(event) {
    const level = parseInt(event.params.level, 10)
    this.editor.chain().focus().toggleHeading({ level }).run()
  }

  toggleBulletList() {
    this.editor.chain().focus().toggleBulletList().run()
  }

  toggleOrderedList() {
    this.editor.chain().focus().toggleOrderedList().run()
  }

  updateToolbarState(editor) {
    this.element.querySelectorAll('[data-tiptap-state]').forEach(button => {
      const descriptor = button.dataset.tiptapState
      let isActive = false

      if (descriptor.includes(':')) {
        const [name, value] = descriptor.split(':')
        const attrs = {}
        if (name === 'heading') attrs.level = parseInt(value, 10)
        isActive = editor.isActive(name, attrs)
      } else {
        isActive = editor.isActive(descriptor)
      }

      button.setAttribute('aria-pressed', isActive.toString())
      if (isActive) {
        button.classList.add('bg-pink-50', 'text-pink-700')
        button.classList.remove('text-gray-700')
      } else {
        button.classList.remove('bg-pink-50', 'text-pink-700')
        button.classList.add('text-gray-700')
      }
    })
  }
}
