//-----------------------------------------------------------
//	Class:	CriticalDamage_UIListenerUpgrade
//	Author: Mr. Nice
//	
//-----------------------------------------------------------
// WARNING!! Live Proxy, handle with care! If any of the non-
// overriden methods or properties not setup in OnCreation()
// are accessed, BAD THINGS will happen, and God Forbid it
// ever  actually be commited to a XComGameState!!
// (Or fed after midnight...)
//-----------------------------------------------------------

class XComGameState_ItemCrit extends XComGameState_Item;

var XComGameState_Item RealkItem;
var X2CritItemTemplate ProxyTemplate;

var string StatsSuffix[ECharStatType.EnumCount];
var byte bArmourStats[ECharStatType.EnumCount];

var localized string CriticalDamageLabel;

static function XComGameState_Item CreateProxy(XComGameState_Item kItem, optional StateObjectReference UnitRef)
{
	local XComGameState_ItemCrit ProxykItem;

	if (kItem==none)
		return kItem;

	ProxykItem=new class 'XComGameState_ItemCrit';
	ProxykItem.RealkItem=kItem;
	ProxykItem.m_ItemTemplate=kItem.GetMyTemplate();
	//ProxykItem.OwnerStateObject=UnitRef.ObjectID!=0 ? UnitRef : kItem.OwnerStateObject;
	ProxykItem.ProxyTemplate=new class'X2CritItemTemplate';
	ProxykItem.ProxyTemplate.RealTemplate= ProxykItem.m_ItemTemplate;
	ProxykItem.ProxyTemplate.ObjectID=kItem.ObjectID;
	ProxykItem.ProxyTemplate.WeaponTech=X2WeaponTemplate(ProxykItem.m_ItemTemplate).WeaponTech;

	return ProxykItem;
}

simulated function X2ItemTemplate GetMyTemplate()
{
	return ProxyTemplate;
}

simulated function array<UISummary_TacaticalText> GetUISummary_TacticalText()
{
	return RealkItem.GetUISummary_TacticalText();
}

simulated function array<UISummary_TacaticalText> GetUISummary_TacticalTextUpgrades()
{
	return RealkItem.GetUISummary_TacticalTextUpgrades();
}

simulated function array<UISummary_TacaticalText> GetUISummary_TacticalTextAbilities()
{
	return RealkItem.GetUISummary_TacticalTextAbilities();
}

simulated function array<X2WeaponUpgradeTemplate> GetMyWeaponUpgradeTemplates()
{
	return RealkItem.GetMyWeaponUpgradeTemplates();
}

simulated function array<UISummary_ItemStat> GetUISummary_DefaultStats()
{
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_Tech BreakthroughTech;
	local X2AbilityTemplateManager AbilityTemplateMan;
	local StateObjectReference ObjectRef;
	local X2TechTemplate TechTemplate;
	local X2AbilityTemplate AbilityTemplate;
	local X2Effect TargetEffect;
	local X2Effect_PersistentStatChange StatChangeEffect;
	local array <StatChange> StatChanges;
	local StatChange Change, EmptyChange;
	local UIStatMarkup StatMarkup;
	local array<UISummary_ItemStat> Stats; 
	local UISummary_ItemStat Item; 
	local int i;
	local X2EquipmentTemplate EquipmentTemplate;
	local delegate<X2StrategyGameRulesetDataStructures.SpecialRequirementsDelegate> ShouldStatDisplayFn;
	local array<string> BonusLabels;
	local UISummary_ItemStat		CategoryItem;

	EquipmentTemplate = X2EquipmentTemplate(m_ItemTemplate);

	CategoryItem.Label = `CAPS(class'UIPersonnel'.default.m_strButtonLabels[ePersonnelSoldierSortType_Class]); 
	CategoryItem.Value = `CAPS(GetLocalizedCategory(m_ItemTemplate));
	Stats.AddItem(CategoryItem);

	if( EquipmentTemplate != None )
	{
		// Search XComHQ for any breakthrough techs which modify the stats on this item, and store those stat changes
		XComHQ = `XCOMHQ;
		if (XComHQ != none)
		{
			AbilityTemplateMan = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();

			foreach XComHQ.TacticalTechBreakthroughs(ObjectRef)
			{
				BreakthroughTech = XComGameState_Tech(`XCOMHISTORY.GetGameStateForObjectID(ObjectRef.ObjectID));
				TechTemplate = BreakthroughTech.GetMyTemplate();

				if (TechTemplate.BreakthroughCondition != none && TechTemplate.BreakthroughCondition.MeetsCondition(RealkItem))
				{
					AbilityTemplate = AbilityTemplateMan.FindAbilityTemplate(TechTemplate.RewardName);
					foreach AbilityTemplate.AbilityTargetEffects(TargetEffect)
					{
						StatChangeEffect = X2Effect_PersistentStatChange(TargetEffect);
						foreach StatChangeEffect.m_aStatChanges(Change)
						{
							if (Change.ModOp!=MODOP_Addition) continue;
							i=StatChanges.Find('StatType', Change.StatType);
							if (i!=INDEX_NONE)
								StatChanges[i].StatAmount += Change.StatAmount;
							else StatChanges.AddItem(Change);
						}
					}
				}
			}
		}
	
		BonusLabels.AddItem(class'XLocalizedData'.default.CriticalDamageLabel);//This should really have been called CriticalDamageBonusLabel
		BonusLabels.AddItem(class'XLocalizedData'.default.GrenadeRangeBonusLabel);
		BonusLabels.AddItem(class'XLocalizedData'.default.GrenadeRadiusBonusLabel);

		foreach   EquipmentTemplate.UIStatMarkups(StatMarkUp)
		{
			ShouldStatDisplayFn = StatMarkUp.ShouldStatDisplayFn;
			if (ShouldStatDisplayFn != None && !ShouldStatDisplayFn())
			{
				continue;
			}
			
			// Start with the value from the stat markup
			Item.Label = StatMarkup.StatLabel;
			Item.Value=StatMarkup.StatUnit;
			i=StatChanges.Find('StatType', StatMarkup.StatType);
			if (i!=INDEX_NONE) Change=StatChanges[i];
			else Change=EmptyChange;
			If (Item.Value=="")
			{
				if (StatMarkup.StatType!=eStat_Invalid)
					Item.Value=StatsSuffix[StatMarkup.StatType];
				else
				{
					Switch(StatMarkup.StatLabel)
					{
						case (class'XLocalizedData'.default.BurnChanceLabel):
						case (class'XLocalizedData'.default.StunChanceLabel):
							Item.Value="%";
					}
				}
			}
			if ( 
					BonusLabels.Find(Item.Label)!=INDEX_NONE
					|| m_ItemTemplate.IsA('X2AmmoTemplate')
					|| StatMarkup.StatType!=eStat_Invalid
					&& !(m_ItemTemplate.IsA('X2ArmorTemplate') && bool(bArmourStats[StatMarkup.StatType]))
				)
				Item.ValueState=eUIState_Good;
			// Then check all of the stat change effects from techs and add any appropriate modifiers
			if (PopulateWeaponStat(StatMarkup.StatModifier, Change.StatAmount>0, Change.StatAmount, Item) || StatMarkup.bForceShow)
				Stats.AddItem(Item);
		}
	}

	return Stats; 
}

simulated function array<UISummary_ItemStat> GetUISummary_WeaponStats(optional X2WeaponUpgradeTemplate PreviewUpgradeStats)
{
	//local XComGameState_Item RealkItem;
	local array<UISummary_ItemStat> Stats; 
	local UISummary_ItemStat		Item;
	local UIStatMarkup				StatMarkup;
	local WeaponDamageValue         DamageValue, UpgradeDamageValue;
	local EUISummary_WeaponStats    UpgradeStats;
	local X2WeaponTemplate WeaponTemplate;
	local delegate<X2StrategyGameRulesetDataStructures.SpecialRequirementsDelegate> ShouldStatDisplayFn;
	local int Index, EffectDamage;
	local X2StrategyElementTemplate CHVersion;
	local UISummary_ItemStat		CategoryItem;

	CategoryItem.Label = `CAPS(class'UIPersonnel'.default.m_strButtonLabels[ePersonnelSoldierSortType_Class]); 
	CategoryItem.Value = `CAPS(GetLocalizedCategory(m_ItemTemplate));
	Stats.AddItem(CategoryItem);

	// Safety check: you need to be a weapon to use this. 
	WeaponTemplate = X2WeaponTemplate(m_ItemTemplate);
	if( WeaponTemplate == none ) 
		return Stats; 
	if(PreviewUpgradeStats != none) 
		UpgradeStats = RealkItem.GetUpgradeModifiersForUI(PreviewUpgradeStats);
	else
		UpgradeStats = RealkItem.GetUpgradeModifiersForUI(X2WeaponUpgradeTemplate(m_ItemTemplate));

	// Damage-----------------------------------------------------------------------
	if (!WeaponTemplate.bHideDamageStat)
	{
		CHVersion=class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().FindStrategyElementTemplate('CHXComGameVersion');
		if(CHVersion!=none)
		{
			UpgradeDamageValue=UpgradeStats.DamageValue;
			If(CHXComGameVersionTemplate(CHVersion).GetVersionNumber()<=100160000)
				UpgradeStats.Damage+=UpgradeDamageValue.Damage;
		}
		
		UpgradeDamageValue.Crit-=EffectDamage;
		UpgradeStats.Damage+=EffectDamage;
		// NormalDamage-----------------------------------------------------------------------
		Item.Label = class'XLocalizedData'.default.DamageLabel;
		RealkItem.GetBaseWeaponDamageValue(none, DamageValue);

		if (DamageValue.Damage > 0)
		{
			if (DamageValue.Spread > 0 || DamageValue.PlusOne > 0)
				Item.Value = string(DamageValue.Damage - DamageValue.Spread) $ "-" $ string(DamageValue.Damage + DamageValue.Spread + (DamageValue.PlusOne > 0) ? 1 : 0);
			else
				Item.Value = string(DamageValue.Damage);
		}
		if (UpgradeDamageValue.Spread!=0)
			Item.Value $= AddStatModifier(false, "", UpgradeStats.Damage-UpgradeDamageValue.Spread) $ "-" $
				class'UIUtilities_Text'.static.GetColoredText(string(UpgradeStats.Damage+UpgradeDamageValue.Spread), UpgradeStats.Damage+UpgradeDamageValue.Spread>0 ? eUIState_Good : eUIState_Bad);
		else if (UpgradeStats.Damage!=0)
			Item.Value $= AddStatModifier(false, "", UpgradeStats.Damage);

		if (Item.Value!="")
			Stats.AddItem(Item);
		//TODO: Item.ValueState = bIsDamageModified ? eUIState_Good : eUIState_Normal;

		// CritDamage-----------------------------------------------------------------------
		
		Item.Label = CriticalDamageLabel;
		Item.ValueState=eUIState_Good;
		Item.Value="";
		if (PopulateWeaponStat(DamageValue.Crit, UpgradeDamageValue.Crit!=0, UpgradeDamageValue.Crit, Item))
			Stats.AddItem(Item);

		// Pierce --------------------------------------------------------------------
		Item.Label = class'XLocalizedData'.default.PierceLabel;
		Item.Value="";
		if (PopulateWeaponStat(DamageValue.Pierce, UpgradeDamageValue.Pierce!=0, UpgradeDamageValue.Pierce, Item))
			Stats.AddItem(Item);

		// Shred --------------------------------------------------------------------
		Item.Label = class'XLocalizedData'.default.ShredLabel;
		Item.Value="";

		if (PopulateWeaponStat(WeaponTemplate.BaseDamage.Shred, UpgradeDamageValue.Shred!=0, UpgradeDamageValue.Shred, Item))
			Stats.AddItem(Item);

		// Rupture --------------------------------------------------------------------
		Item.Label = Caps(Localize("BulletShred X2AbilityTemplate", "LocFriendlyName", "XComGame"));
		Item.Value="";
		if (PopulateWeaponStat(DamageValue.Rupture, UpgradeDamageValue.Rupture!=0, UpgradeDamageValue.Rupture, Item))
			Stats.AddItem(Item);
	}
							
	// Clip Size --------------------------------------------------------------------
	if (m_ItemTemplate.ItemCat == 'weapon' && !WeaponTemplate.bHideClipSizeStat && WeaponTemplate.iClipSize>1)
	{
		Item.Label = class'XLocalizedData'.default.ClipSizeLabel;
		Item.Value="";
		if (PopulateWeaponStat(RealkItem.GetItemClipSize(), UpgradeStats.bIsClipSizeModified, UpgradeStats.ClipSize, Item))
			Stats.AddItem(Item);
	}

	// Crit -------------------------------------------------------------------------
	Item.Label = class'XLocalizedData'.default.CriticalChanceLabel;
	Item.Value="";
	if (PopulateWeaponStat(RealkItem.GetItemCritChance(), UpgradeStats.bIsCritModified, UpgradeStats.Crit, Item, true))
		Stats.AddItem(Item);

	// Ensure that any items which are excluded from stat boosts show values that show up in the Soldier Header
	// Mr.Nice: Whelp, Firaxis screwed up and inverted the logic, so aim bonuses either show up in both places or neither!
	// No advantage to hiding it even if it is shown in the Soldier Header, since people will be used to primary weapon
	// aim bonuses showing in both places, so just dump the condition entirely so that secondary weapons show their aim bonus.
	//if (class'UISoldierHeader'.default.EquipmentExcludedFromStatBoosts.Find(m_ItemTemplate.DataName) == INDEX_NONE)
	//{
		// Aim -------------------------------------------------------------------------
		Item.Label = class'XLocalizedData'.default.AimLabel;
		Item.ValueState=eUIState_Good;
		Item.Value="";
		if (PopulateWeaponStat(RealkItem.GetItemAimModifier(), UpgradeStats.bIsAimModified, UpgradeStats.Aim, Item, true))
			Stats.AddItem(Item);
	//}

	// Free Fire
	Item.Label = class'XLocalizedData'.default.FreeFireLabel;
	Item.Value="";
	if (PopulateWeaponStat(0, UpgradeStats.bIsFreeFirePctModified, UpgradeStats.FreeFirePct, Item, true))
		Stats.AddItem(Item);

	// Free Reloads
	Item.Label = class'XLocalizedData'.default.FreeReloadLabel;
	Item.Value="";
	if (PopulateWeaponStat(0, UpgradeStats.bIsFreeReloadsModified, UpgradeStats.FreeReloads, Item))
		Stats.AddItem(Item);

	// Miss Damage
	Item.Label = class'XLocalizedData'.default.MissDamageLabel;
	Item.Value="";
	if (PopulateWeaponStat(0, UpgradeStats.bIsMissDamageModified, UpgradeStats.MissDamage, Item))
		Stats.AddItem(Item);

	// Free Kill
	Item.Label = class'XLocalizedData'.default.FreeKillLabel;
	Item.Value="";
	if (PopulateWeaponStat(0, UpgradeStats.bIsFreeKillPctModified, UpgradeStats.FreeKillPct, Item, true))
		Stats.AddItem(Item);

	// Add any extra stats and benefits
	for (Index = 0; Index < WeaponTemplate.UIStatMarkups.Length; ++Index)
	{
		StatMarkup = WeaponTemplate.UIStatMarkups[Index];
		ShouldStatDisplayFn = StatMarkup.ShouldStatDisplayFn;
		if (ShouldStatDisplayFn != None && !ShouldStatDisplayFn())
		{
			continue;
		}
		//Mr. Nice: Shred now always shows if the weapon shreds, so don't need it from StatMarkups
		if ((StatMarkup.StatModifier != 0 || StatMarkup.bForceShow)
			&& StatMarkup.StatLabel!=class'XLocalizedData'.default.ShredLabel
			&& StatMarkup.StatLabel!=class'XLocalizedData'.default.PierceLabel )
		{
			Item.Label = StatMarkup.StatLabel;
			Item.Value = string(StatMarkup.StatModifier) $ StatMarkup.StatUnit;
			Stats.AddItem(Item);
		}
	}

	return Stats;
}

simulated function bool PopulateWeaponStat(int Value, bool bIsStatModified, int UpgradeValue, out UISummary_ItemStat Item, optional bool bIsPercent)
{
	local string Suffix;

	if (bIsPercent) Suffix="%";
	else Suffix=Item.Value;

	if (Item.ValueState==eUIState_Good)
	{
		Item.Value="+";
		Item.ValueState=eUIState_Normal;
	}
	else Item.Value="";

	if (Value<=0)
	{
		if (UpgradeValue==0)
		{
			Item.Value = "0";
			return false;
		}
		else Item.Value="";
	}
	else Item.Value $= Value $ Suffix;

	if (bIsStatModified) Item.Value $= AddStatModifier(false, "", UpgradeValue,, Suffix);

	return true;
}

simulated function string AddStatModifier(bool bAddCommaSeparator, string Label, int Value, optional int ColorState = eUIState_Normal, optional string PostFix, optional bool bSymbolOnRight)
{
	return Super.AddStatModifier(bAddCommaSeparator, Label, Value, Value<0 ? eUIState_Bad : eUIState_Good, PostFix, bSymbolOnRight);
}

defaultproperties
{
	StatsSuffix[eStat_Dodge]="%";
	StatsSuffix[eStat_Offense]="%";
	StatsSuffix[eStat_Defense]="%";
	StatsSuffix[eStat_CritChance]="%";
	StatsSuffix[eStat_FlankingCritChance]="%";
	StatsSuffix[eStat_FlankingAimBonus]="%";
	StatsSuffix[eStat_ArmorChance]="%";
	bArmourStats[eStat_Dodge]=1;
	bArmourStats[eStat_ArmorMitigation]=1;
}



static private function string GetLocalizedCategory(const X2ItemTemplate UseItemTemplate)
{
	local X2ItemTemplateManager		ItemMgr;
	local X2WeaponTemplate			WeaponTemplate;
	local X2ItemTemplate			ItemTemplate;
	local string					LocCat;

	if (UseItemTemplate.IsA('X2ArmorTemplate'))
	{
		return class'UIArmory_Loadout'.default.m_strInventoryLabels[eInvSlot_Armor];
	}

	WeaponTemplate = X2WeaponTemplate(UseItemTemplate);
	if (WeaponTemplate == none)
	{
		return UseItemTemplate.GetLocalizedCategory();
	}

	LocCat = WeaponTemplate.GetLocalizedCategory();
	if (LocCat != class'XGLocalizedData'.default.WeaponCatUnknown)
	{
		return LocCat;
	}

	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	// Use in-game item localization for unlocalized base game weapon cats.
	switch (WeaponTemplate.WeaponCat)
	{
		case 'utility':
			return class'UIArmory_Loadout'.default.m_strInventoryLabels[eInvSlot_Utility];
		case 'heavy':
			return class'UIArmory_Loadout'.default.m_strInventoryLabels[eInvSlot_HeavyWeapon];
		case 'grenade_launcher':
			ItemTemplate = ItemMgr.FindItemTemplate('GrenadeLauncher_CV');
			if (ItemTemplate != none)
				return ItemTemplate.FriendlyName;
			break;
		case 'gremlin':
			ItemTemplate = ItemMgr.FindItemTemplate('Gremlin_CV');
			if (ItemTemplate != none)
				return ItemTemplate.FriendlyName;
			break;
		case 'vektor_rifle':
			ItemTemplate = ItemMgr.FindItemTemplate('VektorRifle_CV');
			if (ItemTemplate != none)
				return ItemTemplate.FriendlyName;
			break;
		//case 'bullpup':
		//	ItemTemplate = ItemMgr.FindItemTemplate('Bullpup_CV'); 
		//	if (ItemTemplate != none)
		//		return ItemTemplate.FriendlyName; "Kal-7 Bullpup" ugh
		//	break;
		case 'sparkrifle':
			ItemTemplate = ItemMgr.FindItemTemplate('SparkRifle_CV');
			if (ItemTemplate != none)
				return ItemTemplate.FriendlyName; // "Heavy Autocannon"
			break;
		case 'claymore':
			ItemTemplate = ItemMgr.FindItemTemplate('Reaper_Claymore');
			if (ItemTemplate != none)
				return ItemTemplate.FriendlyName;
			break;
		case 'rifle':
			ItemTemplate = ItemMgr.FindItemTemplate('AssaultRifle_CV');
			if (ItemTemplate != none)
				return ItemTemplate.FriendlyName;
			break;
		case 'shotgun':
			ItemTemplate = ItemMgr.FindItemTemplate('Shotgun_CV');
			if (ItemTemplate != none)
				return ItemTemplate.FriendlyName;
			break;
		case 'pistol':
			ItemTemplate = ItemMgr.FindItemTemplate('Pistol_CV');
			if (ItemTemplate != none)
				return ItemTemplate.FriendlyName;
			break;
		case 'cannon':
			ItemTemplate = ItemMgr.FindItemTemplate('Cannon_CV');
			if (ItemTemplate != none)
				return ItemTemplate.FriendlyName;
			break;
		case 'sword':
			ItemTemplate = ItemMgr.FindItemTemplate('Sword_CV');
			if (ItemTemplate != none)
				return ItemTemplate.FriendlyName;
			break;
		case 'sniper_rifle':
			ItemTemplate = ItemMgr.FindItemTemplate('SniperRifle_CV');
			if (ItemTemplate != none)
				return ItemTemplate.FriendlyName;
			break;
		case 'wristblade':
			ItemTemplate = ItemMgr.FindItemTemplate('WristBlade_CV');
			if (ItemTemplate != none)
				return ItemTemplate.FriendlyName;
			break;
		case 'gauntlet':
			ItemTemplate = ItemMgr.FindItemTemplate('ShardGauntlet_CV');
			if (ItemTemplate != none)
				return ItemTemplate.FriendlyName; // "Shard Gauntlets"
			break;
		case 'sparkbit':
			ItemTemplate = ItemMgr.FindItemTemplate('SparkBit_CV');
			if (ItemTemplate != none)
				return ItemTemplate.FriendlyName; // "SPARK BIT"
			break;
		case 'psiamp':
			ItemTemplate = ItemMgr.FindItemTemplate('PsiAmp_CV');
			if (ItemTemplate != none)
				return ItemTemplate.FriendlyName; // "Psi Amp"
			break;
		case 'sidearm':
			ItemTemplate = ItemMgr.FindItemTemplate('Sidearm_CV');
			if (ItemTemplate != none)
				return ItemTemplate.FriendlyName; // "Autopistol"
			break;
		default:
			break;
	}

	return Repl(string(WeaponTemplate.WeaponCat), "_", " ");
}