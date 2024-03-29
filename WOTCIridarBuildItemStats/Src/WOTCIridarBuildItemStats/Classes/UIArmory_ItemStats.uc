class UIArmory_ItemStats extends UIPanel;

// A copy of UIArmory_LoadoutItemTooltip that extends UIPanel instead of UITooltip,
// so its visibility is not dictated by mouse position.
// Surprised it works.

var int PADDING_LEFT;
var int PADDING_RIGHT;
var int PADDING_TOP;
var int PADDING_BOTTOM;
var int CENTER_PADDING;

var int BasicWidth;
var int UpgradeWidth;

var UIScrollingText TitleControl;
var public UIStatList StatListBasic; 
//var public UIStatList StatListUpgrades; 
var public UIPanel StatArea;
var public UIPanel TacticalArea; 
var public UIMask TacticalMask;
var public UITacticalInfoList AbilityItemList, UpgradeItemList, TacticalItemList; 
var public UIMask TacticalAreaMask; 

var string targetPath; //What we look for in the mouse callback path and use for relative location
var bool bFollowMouse; 
var bool bUsePartialPath; // Allow the path to define a higher level and accept longer matches 
var string currentPath; 

var delegate<OnRequestItem> RequestItem; 
delegate XComGameState_Item OnRequestItem( string path );

simulated function UIPanel InitLoadoutItemTooltip(optional name InitName, optional name InitLibID)
{
	local UIPanel Line; 

	InitPanel(InitName, InitLibID);

	Hide();

	width = BasicWidth + UpgradeWidth; 

	//-----------------------

	Spawn(class'UIPanel', self).InitPanel('BGBox', class'UIUtilities_Controls'.const.MC_X2Background).SetSize(width, height);

	TitleControl = Spawn(class'UIScrollingText', self);
	TitleControl.InitScrollingText('ScrollingText', "", width - PADDING_LEFT - PADDING_RIGHT, PADDING_LEFT, PADDING_TOP); 
	
	Line = class'UIUtilities_Controls'.static.CreateDividerLineBeneathControl( TitleControl, none, 2 );

	//-----------------------

	StatArea = Spawn(class'UIPanel', self); 
	StatArea.InitPanel('StatArea').SetPosition(0, Line.Y + 4).SetSize(width, height-Line.Y-4);  // plus 4 to give it a little breathing room away from the line

	StatListBasic = Spawn(class'UIStatList', StatArea);
	StatListBasic.InitStatList('StatListLeft',, 0, 0, width, StatArea.height);
	StatListBasic.OnSizeRealized = OnStatListSizeRealized;
	
	//-----------------------

	TacticalArea = Spawn(class'UIPanel', self); 
	TacticalArea.bAnimateOnInit = false;
	TacticalArea.InitPanel('TacticalArea');

	TacticalMask = Spawn(class'UIMask', self).InitMask('TacticalMask', TacticalArea);
	TacticalMask.SetPosition(TacticalArea.X, TacticalArea.Y); 
	TacticalMask.SetWidth(width);

	AbilityItemList = Spawn(class'UITacticalInfoList', TacticalArea);
	AbilityItemList.InitTacticalInfoList('AbilityItemList',
		, 
		class'XLocalizedData'.default.TacticalTextAbilitiesHeader,
		PADDING_LEFT, 
		PADDING_TOP, 
		width-PADDING_LEFT-PADDING_RIGHT);
	AbilityItemList.OnSizeRealized = OnAbilityListSizeRealized;

	UpgradeItemList = Spawn(class'UITacticalInfoList', TacticalArea);
	UpgradeItemList.InitTacticalInfoList('UpgradeItemList',
		, 
		class'XLocalizedData'.default.TacticalTextUpgradesHeader,
		PADDING_LEFT, 
		PADDING_TOP, 
		width-PADDING_LEFT-PADDING_RIGHT);
	UpgradeItemList.OnSizeRealized = OnUpgradeListSizeRealized;

	TacticalItemList = Spawn(class'UITacticalInfoList', TacticalArea);
	TacticalItemList.InitTacticalInfoList('TacticalItemList',
		, 
		class'XLocalizedData'.default.TacticalTextDescHeader,
		PADDING_LEFT, 
		PADDING_TOP, 
		width-PADDING_LEFT-PADDING_RIGHT);
	TacticalItemList.OnSizeRealized = OnTacticalListSizeRealized;

	return self; 
}

simulated function ShowTooltip()
{
	RefreshData();

	if(bIsVisible)
	{
		//Must call this separately, because if the lists do not actually change size, than the 
		//scrolling never updates on the text size realized callback chain.
		ResetScroll();
		AnimateIn(0);
	}
}

simulated function RefreshData()
{
	local XComGameState_Item	kItem; 
	
	if( RequestItem == none )
	{
		Hide();
		return; 
	}
	
	kItem = RequestItem(currentPath);
	if( kItem == none )
	{
		Hide();
		return; 
	} 

	TitleControl.SetSubTitle( class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS( kItem.GetMyTemplate().GetItemFriendlyName(kItem.ObjectID) ) );
	
	TacticalItemList.RefreshData( kItem.GetUISummary_TacticalText() );
	UpgradeItemList.RefreshData( kItem.GetUISummary_TacticalTextUpgrades() );
	AbilityItemList.RefreshData( kItem.GetUISummary_TacticalTextAbilities() );
	StatListBasic.RefreshData( kItem.GetUISummary_ItemBasicStats(), false ); 
}

simulated function OnStatListSizeRealized()
{
	OnAbilityListSizeRealized();
}

simulated function OnAbilityListSizeRealized()
{
	AbilityItemList.SetY(0);
	AbilityItemList.RealizeLocation();

	OnUpgradeListSizeRealized();
}

simulated function OnUpgradeListSizeRealized()
{
	UpgradeItemList.SetY(AbilityItemList.Height);
	UpgradeItemList.RealizeLocation();

	OnTacticalListSizeRealized();
}

simulated function OnTacticalListSizeRealized()
{
	TacticalItemList.SetY(UpgradeItemList.Y + UpgradeItemList.height);
	TacticalItemList.RealizeLocation();

	ResetScroll();
}

simulated function ResetScroll()
{
	local int TacticalStartY, TacticalTextHeight;

	TacticalArea.ClearScroll();

	TacticalStartY = StatArea.Y + StatListBasic.Height + PADDING_BOTTOM;
	TacticalArea.SetY(TacticalStartY - 5);
	TacticalMask.SetY(TacticalStartY - 5);

	TacticalArea.MC.SetNum("_alpha", 100);

	TacticalTextHeight = Height - TacticalMask.Y - PADDING_BOTTOM;
	TacticalMask.SetHeight(TacticalTextHeight);
	TacticalArea.Height = AbilityItemList.Height + UpgradeItemList.Height + TacticalItemList.Height;
	TacticalArea.AnimateScroll(TacticalArea.Height, TacticalMask.Height);
}
simulated function array<UISummary_ItemStat> AddUpgradeHeader( array<UISummary_ItemStat> Stats )
{
	local UISummary_ItemStat Item; 
	
	if( Stats.length > 0 )
	{
		Item.Label = class'XLocalizedData'.default.UpgradesHeader; 
		Item.Value = " "; //Sending in a space, so it doesn't format as a subheader. 
		Stats.InsertItem(0, Item); 
	}

	return Stats;
}

//Defaults: ------------------------------------------------------------------------------
defaultproperties
{
	height = 524;

	PADDING_LEFT	= 14;
	PADDING_RIGHT	= 14;
	PADDING_TOP		= 10;
	PADDING_BOTTOM	= 10;

	BasicWidth		= 292; 
	UpgradeWidth	= 292;  

	bUsePartialPath = true;
}