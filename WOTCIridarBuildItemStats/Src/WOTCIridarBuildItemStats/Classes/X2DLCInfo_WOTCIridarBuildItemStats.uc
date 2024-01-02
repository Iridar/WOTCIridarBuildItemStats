class X2DLCInfo_WOTCIridarBuildItemStats extends X2DownloadableContentInfo;

exec function SetPos(int X, int Y)
{
	class'UISL_BuildItemStats'.default.StatsX = X;
	class'UISL_BuildItemStats'.default.StatsY = Y;
}

exec function SetSize(int W, int H)
{
	class'UISL_BuildItemStats'.default.StatsW = W;
	class'UISL_BuildItemStats'.default.StatsH = H;
}