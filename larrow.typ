#import "@preview/cetz:0.4.2"

#let arrow-label(lbl, dx: 0pt, dy: 0pt) = [#sym.zws#metadata((dx, dy))#lbl#sym.zws]

#let label-arrow(from, to, bend: 0, tip: "straight", from-tip: none,
                 both-tip: none, stroke: auto, from-offset: (0pt, 0pt),
                 to-offset: (0pt, 0pt), both-offset: (0pt, 0pt),
                 caption: none, caption-options:
                    (frame: "rect", fill: white, stroke: 0pt, padding: 1pt),
                 debug: false
) = context {
    // Only import necessary components for example not to override
    // standard stroke definition.
    import cetz.draw: rect, bezier, circle, line, content

    // These functions return a tuple (line, center-coords, debug-points)
    // Line from given points
    let chain-line(..args) = {
        let chain-center(points) = {
            let length(((ax, ay), (bx, by))) = calc.sqrt(calc.pow(ax - bx, 2) + calc.pow(ay - by, 2))
            let center(chunks, lengths, dist) = {
                let length = lengths.at(0)
                if dist <= length {
                    let ((ax, ay), (bx, by)) = chunks.at(0)
                    (ax + (bx - ax) / length * dist, ay + (by - ay) / lengths.at(0) * dist)
                } else {
                    center(chunks.slice(1), lengths.slice(1), dist - length)
                }
            }

            let chunks = points.windows(2)
            // assert(false, message: repr(points))
            let lengths = chunks.map(length)
            center(chunks, lengths, lengths.sum() / 2)
        }
        (
            line(..args),
            chain-center(args.pos()),
            args.pos().slice(1, -1)
        )
    }
    // Straight line or bezier curve
    let bezier-line((fx, fy), (tx, ty), bend, ..args) = {
        // Vector from "from" label to "to" label.
        let diff-x = tx - fx
        let diff-y = ty - fy
        // Position of the midpoint between two labels (used to position the
        // control point of the quadratic bezier curve).
        let midpoint-x = fx + diff-x / 2
        let midpoint-y = fy + diff-y / 2
        // Magnitude of the difference vector between from and to labels.
        let magnitude-diff = calc.sqrt(calc.pow(diff-x, 2) + calc.pow(diff-y, 2))
        let unit-diff-x
        let unit-diff-y
        if magnitude-diff != 0 {
            // Unit vector of the difference from -> to
            unit-diff-x = diff-x / magnitude-diff
            unit-diff-y = diff-y / magnitude-diff
        } else {
            unit-diff-x = 0
            unit-diff-y = 0
        }
        // Coordinates for the final control point.
        let control-x = midpoint-x + unit-diff-y * bend
        let control-y = midpoint-y + -1 * unit-diff-x * bend

        (
            bezier((fx, fy), (tx, ty), (control-x, control-y), ..args),
            ((control-x + midpoint-x) / 2, (control-y + midpoint-y) / 2),
            ((control-x, control-y),)
        )
    }

    // Where the function call is in the layout. Necessary to place the canvas
    // in the top left corner of the page later.
    let here-loc = locate(here()).position()

    // Get the from position and offsets if available.
    let from-loc = locate(from).position()
    let from-deltas = query(from).first()
    let from-dx
    let from-dy
    if from-deltas.has("value") {
        from-dx = from-deltas.value.at(0).to-absolute().pt()
        from-dy = from-deltas.value.at(1).to-absolute().pt()
    } else { (from-dx, from-dy) = (0, 0) }

    // Get the to position and offsets if available.
    let to-loc = locate(to).position()
    let to-deltas = query(to).first()
    let to-dx
    let to-dy
    if to-deltas.has("value") {
        to-dx = to-deltas.value.at(0).to-absolute().pt()
        to-dy = to-deltas.value.at(1).to-absolute().pt()
    } else { (to-dx, to-dy) = (0, 0) }

    // Coordinates of the from and to positions without offsets so far.
    let fx = from-loc.x.to-absolute().pt()
    let fy = page.height.to-absolute().pt() - from-loc.y.to-absolute().pt()
    let tx = to-loc.x.to-absolute().pt()
    let ty = page.height.to-absolute().pt() - to-loc.y.to-absolute().pt()

    // Apply offsets
    fx = (fx + from-offset.at(0).to-absolute().pt() +
          both-offset.at(0).to-absolute().pt() + from-dx)
    fy = (fy + from-offset.at(1).to-absolute().pt() +
          both-offset.at(1).to-absolute().pt() + from-dy)
    tx = (tx + to-offset.at(0).to-absolute().pt() +
          both-offset.at(0).to-absolute().pt() + to-dx)
    ty = (ty + to-offset.at(1).to-absolute().pt() +
          both-offset.at(1).to-absolute().pt() + to-dy)

    // If tips aren't set together, draw individual marks.
    // Otherwise, draw both-tip for both ends.
    let mark = if (both-tip == none) {(start: from-tip, end: tip)} else {
        (symbol: both-tip)
    }
    // Actual drawing of line.
    place(dx: -1 * here-loc.x, dy: -1 * here-loc.y, cetz.canvas(length: 1pt, {
        // This rectangle is used to force the cetz canvas to take the size of
        // the entire page and thus properly locate coordinates from base typst
        // on the page.
        rect((0, 0), (page.width, page.height), stroke: none)
        let (line, center, debug-points) = (
            if bend == "-|" {
                chain-line((fx, fy), (tx, fy), (tx, ty),
                           mark: mark, stroke: stroke)
            } else if bend == "|-" {
                chain-line((fx, fy), (fx, ty), (tx, ty),
                           mark: mark, stroke: stroke)
            } else if type(bend) == function {
                chain-line((fx, fy), ..bend((fx, fy), (tx, ty)), (tx, ty),
                           mark: mark, stroke: stroke)
            } else if type(bend) in (int, float) {
                bezier-line((fx, fy), (tx, ty), bend,
                            mark: mark, stroke: stroke)
            }
        )
        line
        if caption != none {
            content(center, caption, ..caption-options)
        }
        // If debugging was turned on for the arrow, the starting and end
        // points as well as the control point is marked.
        if debug {
            circle((fx, fy), stroke: green)
            circle((tx, ty), stroke: red)
            debug-points.map(circle.with(stroke: blue)).join()
        }
    }))
}

#let al = arrow-label
#let larw = label-arrow
