import { providerChannel } from '../utils/providerConfig.js';
import { CodeWindow } from './CodeWindow.jsx';
import { StatusBadge } from './StatusBadge.jsx';

export function EnabledBadge({ enabled }) {
  return enabled ? (
    <StatusBadge tone="success" dot>
      Enabled
    </StatusBadge>
  ) : (
    <StatusBadge dot>Disabled</StatusBadge>
  );
}

export function ChannelBadge({ provider }) {
  const channel = providerChannel(provider);
  return channel ? <StatusBadge className="h-5 px-2">{channel}</StatusBadge> : null;
}

function Detail({ label, children }) {
  return (
    <div className="space-y-1.5">
      <dt className="font-medium text-muted-foreground text-xs">{label}</dt>
      <dd className="text-sm">{children}</dd>
    </div>
  );
}

export function ProviderDetails({ provider }) {
  return (
    <div className="space-y-5">
      <dl className="grid grid-cols-2 gap-4 rounded-xl border bg-muted/30 p-4 sm:grid-cols-4">
        <Detail label="ID">
          <code>{provider.id}</code>
        </Detail>
        <Detail label="Display name">{provider['display-name']}</Detail>
        <Detail label="Channel">
          <ChannelBadge provider={provider} />
        </Detail>
        <Detail label="Status">
          <EnabledBadge enabled={provider.enabled} />
        </Detail>
      </dl>
      <CodeWindow title={`${provider.id}.json`}>
        <pre className="max-h-96 overflow-auto p-4 text-xs leading-relaxed">{JSON.stringify(provider, null, 2)}</pre>
      </CodeWindow>
      <p className="text-muted-foreground text-xs">Secret values are masked by the server.</p>
    </div>
  );
}
