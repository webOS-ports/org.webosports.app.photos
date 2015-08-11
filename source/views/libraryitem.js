enyo.kind({
	name: "LibraryItem",
	kind: "enyo.FittableColumns",

	published: {
		imageSource: "",
		title: "",
		lastItem: false
	},

	handlers: {
		ontap: "handleTap",
		ondown: "catchMouseDown",
		onup: "cancelMouseDown",
		ondragstart: "cancelMouseDown"
	},

	components:[
		{name: "albumImage", kind: "enyo.Image", style: "width: 40px; height: 40px; margin-right: 10px;", src: ""},
		{name: "albumTitle", style: "color: lightgrey; line-height: 36px;", fit: true}
	],

	bindings: [
		{from: ".imageSource", to: ".$.albumImage.src"},
		{from: ".title", to: ".$.albumTitle.content"},
		{from: ".lastItem", to: ".style", transform: function(v)
		{
			return v ? "padding: 10px 10px 10px 15px;" : "padding: 10px 10px 10px 15px; border-bottom: 1px groove black";
		}}
	],

	handleTap: function(inSender, inEvent) {
		this.applyStyle("background-color", "CornflowerBlue");
	},
	catchMouseDown: function(inSender, inEvent) {
		this.applyStyle("background-color", "grey");
	},
	cancelMouseDown: function(inSender, inEvent) {
		this.applyStyle("background-color", null);
	},
});