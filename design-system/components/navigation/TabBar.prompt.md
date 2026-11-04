App bottom nav with the coral Create Training button in the middle.

```jsx
<TabBar value="activity" onChange={setTab} centerAction={{ icon: 'plus', label: 'Plan a training', onClick: openCreate }}
  items={[{id:'activity',icon:'house',label:'Activity'},{id:'training',icon:'calendar',label:'Training'},{id:'friends',icon:'users',label:'Friends'},{id:'profile',icon:'user',label:'Profile'}]} />
```
