import { Controller } from "@hotwired/stimulus"
import { Editor } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import { Placeholder } from "@tiptap/extensions"
import Underline from "@tiptap/extension-underline"
import Link from "@tiptap/extension-link"

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
        }),
        Underline,
        Link.configure({ openOnClick: false })
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

  toggleItalic() {
    this.editor.chain().focus().toggleItalic().run()
  }

  toggleStrike() {
    this.editor.chain().focus().toggleStrike().run()
  }

  toggleUnderline() {
    this.editor.chain().focus().toggleUnderline().run()
  }

  toggleCode() {
    this.editor.chain().focus().toggleCode().run()
  }

  toggleCodeBlock() {
    this.editor.chain().focus().toggleCodeBlock().run()
  }

  toggleBlockquote() {
    this.editor.chain().focus().toggleBlockquote().run()
  }

  setHorizontalRule() {
    this.editor.chain().focus().setHorizontalRule().run()
  }

  setLink(event) {
    event.preventDefault()
    const previousUrl = this.editor.getAttributes('link').href || ''
    const url = window.prompt("Enter URL:", previousUrl)
    if (url === null) return
    if (url === '') {
      this.editor.chain().focus().extendMarkRange('link').unsetLink().run()
    } else {
      const normalized = url.trim().toLowerCase()
      if (normalized.startsWith('javascript:') || normalized.startsWith('data:')) {
        console.warn('Tiptap: blocked unsafe link protocol')
        return
      }
      this.editor.chain().focus().extendMarkRange('link').setLink({ href: url }).run()
    }
  }

  undo() {
    this.editor.chain().focus().undo().run()
  }

  redo() {
    this.editor.chain().focus().redo().run()
  }

  updateToolbarState(editor) {
    this.element.querySelectorAll('[data-tiptap-state]').forEach(el => {
      const descriptor = el.dataset.tiptapState
      let isActive = false

      if (descriptor.includes(':')) {
        const [name, value] = descriptor.split(':')
        const attrs = {}
        if (name === 'heading') attrs.level = parseInt(value, 10)
        isActive = editor.isActive(name, attrs)
      } else {
        isActive = editor.isActive(descriptor)
      }

      el.setAttribute('aria-pressed', isActive.toString())
      if (isActive) {
        el.classList.add('bg-pink-50', 'text-pink-700')
        el.classList.remove('text-gray-700')
      } else {
        el.classList.remove('bg-pink-50', 'text-pink-700')
        el.classList.add('text-gray-700')
      }
    })
  }
}
