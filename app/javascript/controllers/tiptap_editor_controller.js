import { Controller } from "@hotwired/stimulus"
import { Editor } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import { Placeholder } from "@tiptap/extensions"
import Underline from "@tiptap/extension-underline"
import Link from "@tiptap/extension-link"
import { Table } from "@tiptap/extension-table"
import TableRow from "@tiptap/extension-table-row"
import TableCell from "@tiptap/extension-table-cell"
import TableHeader from "@tiptap/extension-table-header"
import { BubbleMenu } from "@tiptap/extension-bubble-menu"
import Image from "@tiptap/extension-image"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ["editor", "input", "tableMenu", "imageFileInput"]
  static values = { directUploadUrl: { type: String, default: "/rails/active_storage/direct_uploads" } }

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
        Link.configure({ openOnClick: false }),
        Table.configure({ resizable: false }),
        TableRow,
        TableCell,
        TableHeader,
        BubbleMenu.configure({ element: this.tableMenuTarget, shouldShow: ({ editor }) => editor.isActive('table'), tippyOptions: { placement: 'top' } }),
        Image.configure({ inline: false, allowBase64: false, HTMLAttributes: { class: "tiptap-inline-image" } })
      ],
      content: existingContent,
      onUpdate: ({ editor }) => {
        this.inputTarget.value = editor.getHTML()
      },
      onSelectionUpdate: ({ editor }) => {
        this.updateToolbarState(editor)
        this.updateImageSelectionHandles(editor)
      },
      onTransaction: ({ editor }) => {
        this.updateToolbarState(editor)
      }
    })

    // Sync initial value so an empty form submission doesn't miss the field
    this.inputTarget.value = this.editor.getHTML()

    // Drag-and-drop listeners on the editor target
    this._onDragOver = (event) => {
      event.preventDefault()
      this.editorTarget.classList.add('border-pink-400', 'bg-pink-50')
    }

    this._onDragLeave = (event) => {
      this.editorTarget.classList.remove('border-pink-400', 'bg-pink-50')
    }

    this._onDrop = (event) => {
      event.preventDefault()
      this.editorTarget.classList.remove('border-pink-400', 'bg-pink-50')
      if (event.dataTransfer.files.length > 0) {
        this.uploadImage(event.dataTransfer.files[0])
      }
    }

    this.editorTarget.addEventListener('dragover', this._onDragOver)
    this.editorTarget.addEventListener('dragleave', this._onDragLeave)
    this.editorTarget.addEventListener('drop', this._onDrop)
  }

  disconnect() {
    // Remove drag-and-drop listeners
    if (this._onDragOver) {
      this.editorTarget.removeEventListener('dragover', this._onDragOver)
      this.editorTarget.removeEventListener('dragleave', this._onDragLeave)
      this.editorTarget.removeEventListener('drop', this._onDrop)
    }

    // Clean up any lingering overlays / timers
    this._removeUploadOverlay()
    if (this._errorBannerTimeout) {
      clearTimeout(this._errorBannerTimeout)
      this._errorBannerTimeout = null
    }

    if (this.editor) {
      this.editor.destroy()
      this.editor = null
    }
  }

  teardown() {
    this.disconnect()
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

  insertTable() {
    this.editor.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run()
  }

  addRowBefore() {
    this.editor.chain().focus().addRowBefore().run()
  }

  addRowAfter() {
    this.editor.chain().focus().addRowAfter().run()
  }

  deleteRow() {
    this.editor.chain().focus().deleteRow().run()
  }

  addColumnBefore() {
    this.editor.chain().focus().addColumnBefore().run()
  }

  addColumnAfter() {
    this.editor.chain().focus().addColumnAfter().run()
  }

  deleteColumn() {
    this.editor.chain().focus().deleteColumn().run()
  }

  deleteTable() {
    this.editor.chain().focus().deleteTable().run()
  }

  triggerImageUpload() {
    this.imageFileInputTarget.click()
  }

  handleImageFileSelected(event) {
    const file = event.target.files[0]
    if (!file) return
    this.uploadImage(file)
    // Reset so selecting the same file again fires the change event
    event.target.value = ""
  }

  uploadImage(file) {
    if (!file.type.startsWith('image/')) {
      this.showInlineError('Only image files can be dropped here.')
      return
    }

    this._showUploadOverlay()

    const upload = new DirectUpload(file, this.directUploadUrlValue)
    upload.create((error, blob) => {
      if (error) {
        this._removeUploadOverlay()
        this.showInlineError('Image upload failed. Please try again.')
        return
      }

      // Prompt for alt text
      const altText = window.prompt('Enter alt text for this image (required):')
      if (altText === null) {
        // User cancelled — remove overlay
        this._removeUploadOverlay()
        return
      }

      this._removeUploadOverlay()

      const blobUrl = `/rails/active_storage/blobs/redirect/${blob.signed_id}/${encodeURIComponent(blob.filename)}`
      this.editor.chain().focus().setImage({ src: blobUrl, alt: altText, width: 720 }).run()
    })
  }

  showInlineError(message) {
    const banner = document.createElement('div')
    banner.className = 'tiptap-error-banner'
    banner.setAttribute('contenteditable', 'false')
    banner.textContent = message
    this.element.appendChild(banner)
    this._errorBannerTimeout = setTimeout(() => banner.remove(), 4000)
  }

  _showUploadOverlay() {
    if (this._uploadOverlay) return

    const overlay = document.createElement('div')
    overlay.className = 'tiptap-upload-overlay'
    overlay.setAttribute('contenteditable', 'false')

    const spinner = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
    spinner.setAttribute('xmlns', 'http://www.w3.org/2000/svg')
    spinner.setAttribute('width', '20')
    spinner.setAttribute('height', '20')
    spinner.setAttribute('viewBox', '0 0 24 24')
    spinner.setAttribute('fill', 'none')
    spinner.setAttribute('stroke', 'currentColor')
    spinner.setAttribute('stroke-width', '2')
    spinner.setAttribute('stroke-linecap', 'round')
    spinner.setAttribute('stroke-linejoin', 'round')
    spinner.classList.add('animate-spin')

    const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle')
    circle.setAttribute('cx', '12')
    circle.setAttribute('cy', '12')
    circle.setAttribute('r', '10')
    circle.setAttribute('stroke', '#d1d5db')

    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path')
    path.setAttribute('d', 'M12 2a10 10 0 0 1 10 10')
    path.setAttribute('stroke', '#6b7280')

    spinner.appendChild(circle)
    spinner.appendChild(path)

    const label = document.createElement('span')
    label.textContent = 'Uploading image…'

    overlay.appendChild(spinner)
    overlay.appendChild(label)

    this.element.appendChild(overlay)
    this._uploadOverlay = overlay
  }

  _removeUploadOverlay() {
    if (this._uploadOverlay) {
      this._uploadOverlay.remove()
      this._uploadOverlay = null
    }
  }

  updateImageSelectionHandles(editor) {
    // Remove existing handles
    this.editorTarget.querySelectorAll('.tiptap-resize-handle').forEach(el => el.remove())

    if (!editor.isActive('image')) return

    const selectedImg = this.editorTarget.querySelector('img.ProseMirror-selectednode, img.tiptap-inline-image.ProseMirror-selectednode')
    if (!selectedImg) return

    // Add selection ring
    selectedImg.classList.add('ring-2', 'ring-pink-500')

    const editorRect = this.editorTarget.getBoundingClientRect()
    const imgRect = selectedImg.getBoundingClientRect()

    const corners = [
      { corner: 'nw', left: imgRect.left - editorRect.left - 4, top: imgRect.top - editorRect.top - 4 },
      { corner: 'ne', left: imgRect.right - editorRect.left - 4, top: imgRect.top - editorRect.top - 4 },
      { corner: 'sw', left: imgRect.left - editorRect.left - 4, top: imgRect.bottom - editorRect.top - 4 },
      { corner: 'se', left: imgRect.right - editorRect.left - 4, top: imgRect.bottom - editorRect.top - 4 }
    ]

    corners.forEach(({ corner, left, top }) => {
      const handle = document.createElement('div')
      handle.className = 'tiptap-resize-handle'
      handle.dataset.corner = corner
      handle.style.left = `${left}px`
      handle.style.top = `${top}px`

      handle.addEventListener('mousedown', (startEvent) => {
        startEvent.preventDefault()
        const startX = startEvent.clientX
        const startWidth = parseInt(selectedImg.getAttribute('width'), 10) || selectedImg.naturalWidth || 720
        const editorContentWidth = this.editorTarget.clientWidth

        const onMouseMove = (moveEvent) => {
          const delta = moveEvent.clientX - startX
          const newWidth = Math.min(Math.max(64, startWidth + delta), editorContentWidth)
          editor.commands.updateAttributes('image', { width: newWidth })
        }

        const onMouseUp = () => {
          window.removeEventListener('mousemove', onMouseMove)
          window.removeEventListener('mouseup', onMouseUp)
        }

        window.addEventListener('mousemove', onMouseMove)
        window.addEventListener('mouseup', onMouseUp)
      })

      this.editorTarget.appendChild(handle)
    })
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
