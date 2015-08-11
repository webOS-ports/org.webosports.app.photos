enyo.kind({
	name: "ThumbnailPanel",
	kind: "FittableRows",
	fit: true,

	events: {
		onGrabberDragStart: "",
		onGrabberDragFinish: ""
	},

	components:[
		{kind: "onyx.Toolbar", style: "text-align: center; font-size: 16px; line-height: 26px;", content: "All Photos & Videos"},
		{kind: "enyo.Scroller", style: "background-image: url('assets/bg.png'); border-left: 1px solid #3A3A3A;", fit: true, components: [
			{name: "main", classes: "nice-padding", allowHtml: true}
		]},
		{kind: "onyx.Toolbar", components: [
			{kind: 'onyx.Grabber', ondragstart: 'grabberDragStart', ondragfinish: 'grabberDragFinish'}
		]}
	],
	
	helloWorldTap: function(inSender, inEvent) {
		this.$.main.addContent("The button was tapped.<br/>");
	},

	grabberDragStart: function(inSender, inEvent) {
		this.doGrabberDragStart();
	},

	grabberDragFinish: function(inSender, inEvent) {
		this.doGrabberDragFinish();
	},
});