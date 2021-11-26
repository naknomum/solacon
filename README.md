# solacon

A *solacon* is a varition of an [identicon](https://en.wikipedia.org/wiki/Identicon), in the form of a solar/spiral/floral shape.
This is also known as a "visual hash".

The solacon is **seeded with a value** (string) which determines the shape, symmetry, and shades of the image.

The SVG file contains all the javascript to generate the content, so one only needs to set attributes (e.g. `data-value`) on the object
that is embedding the svg.

![Solacon.svg](Solacon.svg.png "Solacon.svg")

## Example

Try out some [dynamical examples](https://naknomum.github.io/solacon-example/) of **solacons** in action.


## Usage

```javascript
<object type="image/svg+xml" style="width: 500px; height: 500px;" id="svg-obj"
	data="solacon.svg"
	data-value="Hello world."
	data-rgb="0, 30, 255"
></object>


// the parent document can alter the solacon
var svgObj = document.getElementById('svg-obj');
svgObj.setRGB('100, 150, 200');
svgObj.generate('some new value');
svgObj.setRGB();         // random color
svgObj.generate();       // random seed value
svgObj.setRGBFromHash(); // color is based off hashValue (default behavior)
svgObj.refresh();        // applies color change to current shape
```

## Similar projects

Another identicon project of mine, [Hexicon.js](https://github.com/naknomum/hexicon).

For related work, check out [Awesome Identicons](https://github.com/drhus/awesome-identicons), a curated list of _visual hashes_ maintained by **Husam ABBOUD**.

