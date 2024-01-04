class DelayedInitActor extends Actor;

var delegate<DelayedInitDelegate> DelayedInitFn;
delegate DelayedInitDelegate();

function ActivateTimer()
{
	SetTimer(0.2f, false, nameof(TimerFunction));	
}

private function TimerFunction()
{
	if (DelayedInitFn != none)
	{
		DelayedInitFn();
	}
	self.Destroy();
}