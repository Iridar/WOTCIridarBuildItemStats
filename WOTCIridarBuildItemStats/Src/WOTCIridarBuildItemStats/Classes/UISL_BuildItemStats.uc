class UISL_BuildItemStats extends UIScreenListener config(UI);

// This mod is suboptimal in a lot of places, so not a great example for learning.

var private bool bInitDone;

var private config int ButtonX, ButtonY, ButtonH;
var private config int StatsX, StatsY, StatsW, StatsH;
var private config bool bDisplayStats;
var config bool bLog;

var private string SelectedItemPath; // weak reference to the selected list item in the build items menu.

struct ButtonDelegateStruct
{
	var name ButtonName;
	var delegate<OnClickedDelegate> ButtonClickedDelegate;
};
var private array<ButtonDelegateStruct> ButtonDelegates;
var private delegate<OnItemSelectedCallback> OriginalSelectedItemChanged;

delegate OnClickedDelegate(UIButton Button);
delegate OnItemSelectedCallback(UIList ContainerList, int ItemIndex);

event OnInit(UIScreen Screen)
{
	local DelayedInitActor InitActor;

	if (UIInventory_BuildItems(Screen) != none && !bInitDone)
	{
		bInitDone = true;

		// [WOTC] Filtered Build Items Menu - pops the original UIInventory_BuildItems from the stack
		// to push the replacement screen that extends it.
		// When that happens, BuildItems.List.OnSelectionChanged is 'none', 
		// so sidestep the issue by delaying the init.
		// Timers don't seem to run on popped screens, so put the timer on an Actor.    
		
		InitActor = `XCOMGRI.Spawn(class'DelayedInitActor');
		InitActor.DelayedInitFn = DelayedInit;
		InitActor.ActivateTimer();
		  
		//`XCOMGRI.SetTimer(0.2f, false, nameof(DelayedInit));	

		`AMLOG("Scheduled delayed init for screen:" @ Screen.Class.Name);
	}
}

private function DelayedInit()
{
	local UIInventory_BuildItems	BuildItems;
	local UIButton					Button;
	local UIArmory_ItemStats		ItemStats;
	local array<UIPanel>			TabButtons;
	local UIPanel					TabButton;
	local ButtonDelegateStruct		ButtonDelegate;
	local UIScreen					CurrentScreen;

	bInitDone = false;

	CurrentScreen = `SCREENSTACK.GetCurrentScreen();
	`AMLOG("Current screen:" @ CurrentScreen.Class.Name);

	BuildItems = UIInventory_BuildItems(CurrentScreen);
	if (BuildItems == none)
		return;

	if (BuildItems.List == none)
		return;

	`AMLOG("Performing Init for Screen Class:" @ BuildItems.Class.Name @ "Width:" @ BuildItems.Width @ "X:" @ BuildItems.X);

	// When switching between tabs, we need to hide the vanilla information text, 
	// so replace the tab button OnClicked delegates, storing the originals.
	BuildItems.GetChildrenOfType(class'UIButton', TabButtons);
	foreach TabButtons(TabButton)
	{
		Button = UIButton(TabButton);
		if (Left(string(TabButton.MCName), Len("inventoryTab")) == "inventoryTab")
		{
			ButtonDelegate.ButtonName = Button.MCName;
			ButtonDelegate.ButtonClickedDelegate = Button.OnClickedDelegate;
			ButtonDelegates.AddItem(ButtonDelegate);

			Button.OnClickedDelegate = OnTabButtonClicked;

			`AMLOG("Storing delegate for Tab button:" @ Button.MCName);
		}
	}
	
	// Create "Info" button which will toggle the stats panel.
	Button = BuildItems.Spawn(class'UIButton', BuildItems.ListContainer);
	Button.InitButton('IRI_Engineering_ToggleStats_Button', Localize("UIControllerMap", "m_sInfo", "XComGame"), OnButtonClicked);
	Button.SetX(ButtonX);
	Button.SetY(ButtonY);
	Button.SetHeight(ButtonH);

	// Create the stats panel.
	ItemStats = BuildItems.Spawn(class'UIArmory_ItemStats', BuildItems.ListContainer);
	ItemStats.BasicWidth = StatsW;
	ItemStats.Height = StatsH;
	ItemStats.InitLoadoutItemTooltip('IRI_Engineering_ItemStats');
	ItemStats.bUsePartialPath = true;
	ItemStats.targetPath = string(BuildItems.MCPath); 
	ItemStats.RequestItem = TooltipRequestItemFromPath; 
	ItemStats.SetPosition(StatsX, StatsY);

	`AMLOG("Storing delegate for UIList:" @ string(BuildItems.List.OnSelectionChanged));

	OriginalSelectedItemChanged = BuildItems.List.OnSelectionChanged;
	BuildItems.List.OnSelectionChanged = SelectedItemChanged;
	
	// Run this immediately in case bDisplayStats was set to true in config 
	// or persists from the previous visit to the engineering screen.
	SelectedItemChanged(BuildItems.List, BuildItems.List.SelectedIndex);
}

event OnRemoved(UIScreen Screen)
{
	if (UIInventory_BuildItems(Screen) != none)
	{
		// Prevent a garbage collection crash by removing references to delegates when leaving the Engineering screen.
		ButtonDelegates.Length = 0;
		OriginalSelectedItemChanged = none;

		`AMLOG("Performing cleanup for screen:" @ Screen.Class.Name);
		
		if (`XCOMGRI.IsTimerActive(nameof(DelayedInit)))
		{
			`XCOMGRI.ClearTimer(nameof(DelayedInit));
		}

		bInitDone = false;
	}
}

// When the user is switching tabs, hide the vanilla description, if stats panel is shown.
private function OnTabButtonClicked(UIButton Button)
{	
	local ButtonDelegateStruct ButtonDelegate;
	local delegate<OnClickedDelegate> ButtonClickedDelegate;

	foreach ButtonDelegates(ButtonDelegate)
	{
		if (Button.MCName == ButtonDelegate.ButtonName)
		{
			// Can't run delegates directly from structs, apparently.
			ButtonClickedDelegate = ButtonDelegate.ButtonClickedDelegate;
			if (ButtonClickedDelegate != none)
			{
				`AMLOG("Tab button clicked:" @ Button.MCName);
				ButtonClickedDelegate(Button);
			}

			UpdateVanillaDescription(Button);
			break;
		}
	}
}

private function UpdateStatsVisibility(UIArmory_ItemStats ItemStats)
{
	if (bDisplayStats)
	{
		ItemStats.ShowTooltip();
		ItemStats.Show();
	}
	else
	{
		ItemStats.Hide();
	}
}

// Use some unholy hackery from MrNice. Highly likely that it's not actually necessary,
// but I can't be foxed to unwrap this noodlery.
private function XComGameState_Item TooltipRequestItemFromPath(string currentPath)
{
	local XComGameState_Item		ItemState;
	local XComGameState				FakeGameState;
	local XComGameState_Item		ProxyItem;
	local UIInventory_ListItem		ListItem;
	local X2ItemTemplate			ItemTemplate;
	local X2ItemTemplateManager		ItemMgr;
	
	ListItem = UIInventory_ListItem(FindObject(SelectedItemPath, class'UIInventory_ListItem'));
	if (ListItem == none)
		return none;

	ItemTemplate = ListItem.ItemTemplate;
	if (ItemTemplate == none)
		return none;

	if (X2SchematicTemplate(ItemTemplate) != none)
	{
		ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

		ItemTemplate = ItemMgr.FindItemTemplate(X2SchematicTemplate(ItemTemplate).ReferenceItemTemplate);
		if (ItemTemplate == none)
			return none;
	}

	FakeGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState();
	ItemState = XComGameState_Item(FakeGameState.CreateNewStateObject(class'XComGameState_Item', ItemTemplate));
	ProxyItem = class'XComGameState_ItemCrit'.static.CreateProxy(ItemState);
	`XCOMHISTORY.CleanupPendingGameState(FakeGameState);

	return ProxyItem;
}

private function OnButtonClicked(UIButton Button)
{	
	local UIInventory_BuildItems BuildItems;

	bDisplayStats = !bDisplayStats;

	`AMLOG("Info button clicked, Display Stats:" @ bDisplayStats);

	BuildItems = UIInventory_BuildItems(Button.GetParent(class'UIInventory_BuildItems', true));
	if (BuildItems != none)
	{
		SelectedItemChanged(BuildItems.List, BuildItems.List.SelectedIndex);
	}	
	else
	{
		`AMLOG("No Build Items screen!");
	}
}

private function SelectedItemChanged(UIList ContainerList, int ItemIndex)
{
	local UIInventory_BuildItems	BuildItems;
	local UIArmory_ItemStats		ItemStats;

	`AMLOG("Selected item changed:" @ ItemIndex);
	`AMLOG(string(OriginalSelectedItemChanged));

	// Run the original method
	if (OriginalSelectedItemChanged != none)
	{
		OriginalSelectedItemChanged(ContainerList, ItemIndex);
	}

	BuildItems = UIInventory_BuildItems(ContainerList.GetParent(class'UIInventory_BuildItems', true));
	if (BuildItems == none)
	{
		return;
	}
	else
	{
		`AMLOG("No Build Items screen!");
	}

	// Store a weak reference to the selected list item path so it can be accessed from TooltipRequestItemFromPath()
	SelectedItemPath = PathName(ContainerList.GetSelectedItem());

	ItemStats = UIArmory_ItemStats(BuildItems.GetChildByName('IRI_Engineering_ItemStats'));
	if (ItemStats != none)
	{
		UpdateVanillaDescription(BuildItems);
		UpdateStatsVisibility(ItemStats);
	}
	else
	{
		`AMLOG("Missing Item Stats panel.");
	}
}

private function UpdateVanillaDescription(const UIPanel ParentPanel)
{
	local UIInventory_BuildItems BuildItems;

	if (!bDisplayStats)
		return;

	BuildItems = UIInventory_BuildItems(ParentPanel);
	if (BuildItems == none)
	{
		BuildItems = UIInventory_BuildItems(ParentPanel.GetParent(class'UIInventory_BuildItems', true));
		if (BuildItems == none)
			return;
	}
	`AMLOG("Hiding vanilla description.");
		
	BuildItems.ItemCard.PopulateData("", "", "", "");

	BuildItems.ItemCard.mc.BeginFunctionOp("PopulateCostData");
	BuildItems.ItemCard.mc.QueueString("");
	BuildItems.ItemCard.mc.QueueString("");
	BuildItems.ItemCard.mc.QueueString("");
	BuildItems.ItemCard.mc.QueueString("");
	BuildItems.ItemCard.mc.QueueString("");
	BuildItems.ItemCard.mc.EndOp();
}

