class UISL_BuildItemStats extends UIScreenListener config(UI);

var config private bool bDisplayStats;

var config int ButtonX, ButtonY, ButtonH;

var config int StatsX, StatsY, StatsW, StatsH;

var private string SelectedItemPath;

// TODO: Fix hiding the panel
// TODO: Hide text when switching tabs
// TODO: Add weapon category somewhere class'UIPersonnel'.default.m_strButtonLabels[ePersonnelSoldierSortType_Class]
// TODO: add "enabled by default" config bool

event OnInit(UIScreen Screen)
{
	local UIInventory_BuildItems			BuildItems;
	local UIButton							Button;
	local UIArmory_LoadoutItemTooltip		ItemStats;

	BuildItems = UIInventory_BuildItems(Screen);
	if (BuildItems == none)
	{
		return;
	}

	if (BuildItems.List == none)
	{
		`AMLOG("No UIList, exiting");
		return;
	}
	
	Button = BuildItems.Spawn(class'UIButton', BuildItems.ListContainer);
	Button.InitButton('IRI_Engineering_ToggleStats_Button', Localize("UIControllerMap", "m_sInfo", "XComGame"), OnButtonClicked);
	Button.SetX(ButtonX);
	Button.SetY(ButtonY);
	Button.SetHeight(ButtonH);

	ItemStats = BuildItems.Spawn(class'UIArmory_LoadoutItemTooltip', BuildItems.ListContainer);
	ItemStats.BasicWidth = StatsW;
	ItemStats.Height = StatsH;
	ItemStats.InitLoadoutItemTooltip('IRI_Engineering_ItemStats');
	ItemStats.bUsePartialPath = true;
	ItemStats.targetPath = string(BuildItems.MCPath); 
	ItemStats.RequestItem = TooltipRequestItemFromPath; 
	ItemStats.ID = BuildItems.Movie.Pres.m_kTooltipMgr.AddPreformedTooltip(ItemStats);
	ItemStats.tDelay = 0; // instant tooltips!
	ItemStats.SetPosition(StatsX, StatsY);
	UpdateStatsVisibility(ItemStats);

	BuildItems.List.OnSelectionChanged = SelectedItemChanged;
}

private function UpdateStatsVisibility(UIArmory_LoadoutItemTooltip ItemStats)
{
	if (bDisplayStats)
	{
		
		//ItemStats.ShowTooltip();
		ItemStats.Show();
	}
	else
	{
		// I couldn't figure out how to toggle this panel's visibility, conventional methods refused to work,
		// so as a hacky workaround, just move the panel off the screen when it's not needed.
		//ItemStats.SetPosition(2000, 2000);
		//ItemStats.HideTooltip();
		ItemStats.Hide();
	}
}

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

	BuildItems = UIInventory_BuildItems(Button.GetParent(class'UIInventory_BuildItems'));
	if (BuildItems != none)
	{
		SelectedItemChanged(BuildItems.List, BuildItems.List.SelectedIndex);
	}	
}

private function SelectedItemChanged(UIList ContainerList, int ItemIndex)
{
	local UIInventory_BuildItems		BuildItems;
	local UIArmory_LoadoutItemTooltip	ItemStats;

	BuildItems = UIInventory_BuildItems(ContainerList.GetParent(class'UIInventory_BuildItems'));
	if (BuildItems == none)
	{
		`AMLOG("No Build Items screen, exiting");
		return;
	}

	BuildItems.SelectedItemChanged(ContainerList, ItemIndex);

	`AMLOG("Selected item:" @ ItemIndex);

	SelectedItemPath = PathName(ContainerList.GetSelectedItem());

	ItemStats = UIArmory_LoadoutItemTooltip(BuildItems.GetChildByName('IRI_Engineering_ItemStats'));
	if (ItemStats != none)
	{
		UpdateItemStatsPanel(ContainerList, ItemIndex);
		UpdateStatsVisibility(ItemStats);
	}
}

private function UpdateItemStatsPanel(UIList ContainerList, int ItemIndex)
{
	local UIInventory_ListItem				ListItem;
	local UIInventory_BuildItems			BuildItems;

	if (!bDisplayStats)
		return;

	ListItem = UIInventory_ListItem(ContainerList.GetItem(ItemIndex));
	if (ListItem == none)
		return;
	
	if (ListItem.ItemTemplate == none)
		return;

	`AMLOG("Selected item:" @ ListItem.ItemTemplate.DataName);
			
	BuildItems = UIInventory_BuildItems(ListItem.GetParent(class'UIInventory_BuildItems'));
	if (BuildItems == none)
		return;
		
	BuildItems.ItemCard.PopulateData("", "", "", "");
	//BuildItems.ItemCard.SetItemImages(ListItem.ItemTemplate, ListItem.ItemRef);

	BuildItems.ItemCard.mc.BeginFunctionOp("PopulateCostData");
	BuildItems.ItemCard.mc.QueueString("");
	BuildItems.ItemCard.mc.QueueString("");
	BuildItems.ItemCard.mc.QueueString("");
	BuildItems.ItemCard.mc.QueueString("");
	BuildItems.ItemCard.mc.QueueString("");
	BuildItems.ItemCard.mc.EndOp();
}

