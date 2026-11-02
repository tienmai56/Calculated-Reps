Single-choice option — post visibility, intensity level.

```jsx
const [v, setV] = React.useState('gym');
<Radio value="public" label="Everyone" checked={v==='public'} onChange={setV} />
<Radio value="gym" label="My gym only" checked={v==='gym'} onChange={setV} />
```
