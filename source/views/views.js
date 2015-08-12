/**
	For simple applications, you might define all of your views in this file.  
	For more complex applications, you might choose to separate these kind definitions 
	into multiple files under this folder.
*/

enyo.kind({
	name: "myapp.MainView",
	kind: "enyo.Panels",
	arrangerKind: "CollapsingArranger",
	draggable: false,
	components: [
		{kind: "LibraryPanel"},
		{kind: "ThumbnailPanel", onGrabberDragStart: "handleGrabberDragStart", onGrabberDragFinish: "handleGrabberDragFinish"}
	],

	handleGrabberDragStart: function(inSender, inEvent) {
		this.set("draggable", true);
	},

	handleGrabberDragFinish: function(inSender, inEvent) {
		this.set("draggable", false);
	},
});
