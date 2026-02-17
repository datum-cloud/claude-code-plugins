# Pattern Registry

Canonical UI patterns for consistency across Datum Cloud interfaces.

## Status Indicators

### Status Badge

```tsx
<Badge variant={status}>
  {statusLabel}
</Badge>

// Variants: success, warning, error, info, neutral
```

| Status | Color Token | Example |
|--------|-------------|---------|
| Running | `status-success` | Active resources |
| Pending | `status-warning` | Creating, updating |
| Failed | `status-error` | Error states |
| Unknown | `status-info` | Transitional |

### Severity Badge

For insights and alerts:

| Severity | Color | Usage |
|----------|-------|-------|
| Critical | Red | Immediate action needed |
| Warning | Yellow | Should address soon |
| Info | Blue | Informational |

## Data Tables

### Structure

```tsx
<Table>
  <TableHeader>
    <TableRow>
      <TableHead>Name</TableHead>
      <TableHead>Status</TableHead>
      <TableHead>Created</TableHead>
      <TableHead>Actions</TableHead>
    </TableRow>
  </TableHeader>
  <TableBody>
    {items.map(item => (
      <TableRow key={item.id}>
        <TableCell>{item.name}</TableCell>
        <TableCell><StatusBadge status={item.status} /></TableCell>
        <TableCell>{formatDate(item.createdAt)}</TableCell>
        <TableCell><ActionsMenu item={item} /></TableCell>
      </TableRow>
    ))}
  </TableBody>
</Table>
```

### Features

- Sortable columns
- Filterable
- Pagination
- Row selection
- Bulk actions

## Forms

### Field Layout

```tsx
<FormField>
  <FormLabel>Field Name</FormLabel>
  <FormControl>
    <Input {...field} />
  </FormControl>
  <FormDescription>Help text</FormDescription>
  <FormMessage /> {/* Error message */}
</FormField>
```

### Validation States

| State | Appearance |
|-------|------------|
| Default | Normal border |
| Focus | Primary border |
| Error | Error border + message |
| Disabled | Muted, no interaction |

## Navigation

### List → Detail

```
/resources           → List page
/resources/:id       → Detail page
/resources/:id/edit  → Edit page
/resources/new       → Create page
```

### Breadcrumbs

```tsx
<Breadcrumb>
  <BreadcrumbItem href="/projects">Projects</BreadcrumbItem>
  <BreadcrumbItem href="/projects/webapp">webapp</BreadcrumbItem>
  <BreadcrumbItem current>Resources</BreadcrumbItem>
</Breadcrumb>
```

## Empty States

```tsx
<EmptyState
  icon={<ResourceIcon />}
  title="No resources yet"
  description="Create your first resource to get started."
  action={<Button>Create Resource</Button>}
/>
```

## Loading States

### Skeleton

Match the layout of the loaded content:

```tsx
<Skeleton className="h-4 w-[200px]" /> {/* Text line */}
<Skeleton className="h-10 w-full" />  {/* Input */}
<Skeleton className="h-[200px]" />    {/* Card */}
```

### Spinner

For actions, not page loads:

```tsx
<Button disabled>
  <Spinner /> Creating...
</Button>
```

## Error States

```tsx
<ErrorState
  title="Something went wrong"
  description={error.message}
  action={<Button onClick={retry}>Try again</Button>}
/>
```
