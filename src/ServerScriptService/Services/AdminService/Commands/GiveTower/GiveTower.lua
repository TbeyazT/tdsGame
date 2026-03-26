return {
	Name = "GiveTower";
	Aliases = {"GT"};
	Description = "Gives Tower.";
	Group = "DefaultAdmin";
	Args = {
		{
			Type = "player";
			Name = "player";
			Description = "player.";
		},
        {
            Type = "string",
            Name = "TowerName",
            Description = "TowerName",
        }
	};
}