//-----------------------------------------------------------
//	Class:	CriticalDamage_UIListenerUpgrade
//	Author: Mr. Nice
//	
//-----------------------------------------------------------
// WARNING!! Live Proxy, handle with care! Nothing other than
// GetItemFriendlyName() is safe to access.
//-----------------------------------------------------------

class X2CritItemTemplate extends X2WeaponTemplate;

var X2ItemTemplate RealTemplate;

var int ObjectID;

function string GetItemFriendlyName(optional int ItemID = 0, optional bool bShowSquadUpgrade)
{
	return RealTemplate.GetItemFriendlyName(ObjectID, bShowSquadUpgrade);
}