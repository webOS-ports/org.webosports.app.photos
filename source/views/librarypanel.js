enyo.kind({
	name: "LibraryPanel",
	kind: "FittableRows",
	fit: true,

	style: "min-width: 300px;",

	components:[
		{kind: "onyx.Toolbar", style: "text-align: center; font-size: 16px; line-height: 26px;", content: "Libraries & Albums"},
		{kind: "enyo.Scroller", fit: true, style: "background-image: url('assets/bg-library.png');", components: [
			{kind: "enyo.FittableColumns", style: "margin: 15px 15px 5px 15px;", components:[
				{style: "color: white; font-size: 16px; margin-right: 5px; text-transform: uppercase;", content: "Libraries"},
				{fit: true, components: [
					{tag: "hr"}
				]},
				{name: "expandCollapseButton", kind: "enyo.Image", src: "assets/expanded.png"}
			]},
			{kind: "LibraryItem", imageSource: "assets/allphotos.png", title: "All Photos & Videos"},
			{kind: "LibraryItem", imageSource: "assets/luneos-logo.png", title: "My LuneOS Device", lastItem: true},
			{kind: "enyo.FittableColumns", style: "margin: 10px 0 25px 15px;", components:[
				{style: "color: white; font-size: 16px; margin-right: 5px; text-transform: uppercase;", content: "All Albums"},
				{fit: true, components: [
					{tag: "hr"}
				]}
			]},
			{name: "main", classes: "nice-padding", allowHtml: true}
		]},
		{kind: "onyx.Toolbar", style: "text-align: center;", components: [
			{kind: "onyx.Button", content: "New Album", ontap: "newAlbumTap"}
		]}
	],
	helloWorldTap: function(inSender, inEvent) {
		this.$.main.addContent("The button was tapped.<br/>");
	},
});