Bottom sheet or centered modal over a 72% mat overlay.

```jsx
<Dialog variant="modal" title="Delete session?" description="This removes it from your log and streak."
  onClose={close} actions={<><Button variant="secondary" fullWidth>Cancel</Button><Button variant="danger" fullWidth>Delete</Button></>} />
<Dialog variant="sheet" title="Tag a partner" contained onClose={close}>…</Dialog>
```
- Sheet: 24px top radius, grab handle. Use `contained` inside phone frames.
