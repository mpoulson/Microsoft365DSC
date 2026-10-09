# AzureResourceProvider

## Description

Configures the registration of an Azure resource provider in a subscription.

The resource is the declarative equivalent of `Get-AzResourceProvider`,
`Register-AzResourceProvider` and `Unregister-AzResourceProvider`.

## Identity

Registration is a per subscription setting, so both `ProviderNamespace` and
`SubscriptionId` are keys. The same namespace can be registered in one
subscription and not in another, and each of those is a separate instance.

`Ensure = 'Present'` means the namespace is registered in the subscription and
`Ensure = 'Absent'` means it is not.

## Subscription context

The three resource provider cmdlets carry no subscription parameter. They act on
whichever subscription the Az context currently points at, so this resource moves
the context with `Set-AzContext` before every read and every change. That is a
side effect on the shared Az session: after a run the context is left on the last
subscription the resource touched. Configurations that mix this resource with
other Azure resources that rely on an ambient context should set their own
context explicitly rather than assume the one they started with.

## Registration state

`RegistrationState` reports what Azure returns: `Registered`, `NotRegistered`,
`Registering` or `Unregistering`. It is excluded from drift evaluation, because
registering and unregistering are asynchronous and the transitional states would
otherwise be reported as drift on a subscription that is converging correctly.

Neither cmdlet waits for the operation to finish. A run that registers a provider
reports success once Azure has accepted the request, and the provider may still
be in `Registering` for a short while afterwards.

## Unregistering

Azure refuses to unregister a namespace while resources of that type still exist
in the subscription, and the error is surfaced rather than swallowed. Some
namespaces cannot be unregistered at all. Unregistering a namespace that other
resources depend on can break them, so treat `Ensure = 'Absent'` on a
subscription that is in use as a change that needs review.

## Export

Export reads the providers of every subscription returned by `Get-AzSubscription`
and emits one instance per registered namespace, so a tenant with many
subscriptions produces a large number of instances. Passing `SubscriptionId` to
the export narrows it to that one subscription. Namespaces in `NotRegistered`
state are not exported, since the default for an unmanaged namespace is to be
unregistered.
