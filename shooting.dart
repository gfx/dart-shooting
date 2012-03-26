// originated from http://nmi.jp/archives/386
// Copyright 2012, @tkihira. All rights reserved.

#import('dart:html');

/*
class Random { // poor man's drand48
  static num x = 0;
  static num next() {
    x = x * 0x5DEECE66D + 0xB;
    x %= 0xFFFFFFFFFFFF;
    return x * (1.0/(0xFFFFFFFFFFFF+1));
  }
}
num random() => Random.next();
// */
num random() => Math.random();

class Config {
  static final num cols         = 10;
  static final num rows         = 10;
  static final num cellWidth    = 32;
  static final num cellHeight   = 32;
  static final num bulletWidth  = 4;
  static final num bulletHeight = 4;
  static final num bulletSpeed  = 20;
  static final num reloadCount  = 3;

  static final num width  = cols * cellWidth;
  static final num height = rows * cellHeight;
}

class MovingObject {
  num x;
  num y;
  num dx;
  num dy;

  MovingObject(this.x, this.y, this.dx, this.dy);

  // return true while the object lives
  bool update() {
    x += dx;
    y += dy;

    return !(   x <= 0 || x >= Config.width
             || y <= 0 || y >= Config.height);

  }
}

class Bullet extends MovingObject {
  Bullet(x, y, dx, dy) : super(x, y, dx, dy);
}

class Rock extends MovingObject {
  num hp;
  num score;
  String state;

  Rock(x, y, dx, dy, this.hp, this.score, this.state) : super(x, y, dx, dy);
}

class Status {
  List<String> imageName;
  Map<String, Element> images;

  String state = "loading";

  num lastX;
  num lastY;
  num x;
  num y;
  num frameCount;
  num currentTop;

  num dying;

  CanvasRenderingContext2D ctx;
  CanvasRenderingContext2D bgCtx;

  Map<String, Bullet> bullets;

  Map<String, Rock> rocks;

  num score;
  Element scoreElement;

  void drawBackground() {
    num bottom = Config.height + Config.cellHeight - currentTop;
    if(bottom > 0) {
      ctx.drawImage(bgCtx.canvas, 0, currentTop,
        Config.width, bottom, 0, 0, Config.width, bottom);
    }
    if((Config.height - bottom).abs() > 0) {
      ctx.drawImage(bgCtx.canvas, 0, bottom);
    }
  }

  void draw() {
    drawBackground();
    Element image;
    if(state == "gaming") {
      image = images["my"];
    }
    else if(state == "dying") {
      image = images["bomb${dying}"];
      if(++dying > 10) {
        state = "gameover";
      }
    }
    else {
      return;
    }

    assert(image != null);
    ctx.drawImage(image,
      x - (Config.cellWidth  >> 1),
      y - (Config.cellHeight >> 1));
  }

  void drawSpace(num px, num py) {
    Element image = images["space${(random() * 10 + 1).toInt()}"];
    assert(image != null);
    bgCtx.drawImage(image,
      px * Config.cellWidth,
      py * Config.cellHeight);
  }

  Bullet createBullet(num dx, num dy) {
    return new Bullet(
      x, y,
      dx * Config.bulletSpeed,
      dy * Config.bulletSpeed);
  }

  Rock createRock() {
    num level = (frameCount / 500).toInt();

    num px  = x + random() * 100 - 50;
    num py  = y + random() * 100 - 50;
    num fx = random() * Config.width;
    num fy = (level >= 4) ? (random() * 2) * Config.height : 0;

    num r  = Math.atan2(py - fy, px - fx);
    num d  = Math.max(random() * (5.5 + level) + 1.5, 10);

    num hp = (random() * random() * ((5 + level / 4).toInt())).toInt() | 1;

    return new Rock(
      fx,
      fy,
      Math.cos(r) * d,
      Math.sin(r) * d,
      hp,
      hp * hp * 100,
      "rock${(random() * 3 + 1).toInt()}"
    );
  }

  void tick() {
    window.setTimeout(() => tick(), (1000 / 30).toInt());

    if(state == "loading") {
      return;
    }

    ++frameCount;
    if(--currentTop == 0) {
      currentTop = Config.height + Config.cellHeight;
    }
    if( (currentTop % Config.cellHeight) == 0) {
      num line = currentTop / Config.cellHeight - 1;
      for(num px = 0; px < Config.cols; ++px) {
        drawSpace(px, line);
      }
    }

    draw();

    if(state == "gaming" && (frameCount % Config.reloadCount) == 0) {
      bullets["${frameCount}a"] = createBullet(-1, -1);
      bullets["${frameCount}b"] = createBullet( 0, -1);
      bullets["${frameCount}c"] = createBullet( 1, -1);
      bullets["${frameCount}d"] = createBullet(-1,  1);
      bullets["${frameCount}e"] = createBullet( 1,  1);
    }

    if(rocks.length < (5 + frameCount / 500)) {
      rocks["${frameCount}r"] = createRock();
    }

    for(String key in bullets.getKeys()) {
      Bullet bullet = bullets[key];

      if(bullet.update()) {
        ctx.drawImage(images["bullet"],
          bullet.x - (Config.bulletWidth  >> 1),
          bullet.y - (Config.bulletHeight >> 1));

        for(Rock rock in rocks.getValues()) {
          if(    (bullet.x - rock.x).abs() < (Config.cellWidth >> 1)
              && (bullet.y - rock.y).abs() < (Config.cellHeight >> 1)) {
            if(rock.hp > 0) {
              bullets.remove(key);
              if(--rock.hp == 0) {
                score = Math.min(score + rock.score, 999999999);

                String fillz = "000000000".substring(
                  0, 9 - score.toString().length
                );
                scoreElement.innerHTML = "$fillz$score";
                rock.dx = rock.dy = 0;
                rock.state = "bomb1";
              }
              else {
                rock.state = "${rock.state}w".substring(0, 6);
              }
            }
          }
        }
      }
      else {
        bullets.remove(key);
      }
    } // end for each bullets

    for(String key in rocks.getKeys()) {
      Rock rock = rocks[key];
      if(rock.update()) {
        ctx.drawImage(images[rock.state],
          rock.x - (Config.cellWidth >> 1),
          rock.y - (Config.cellHeight >> 1));

        if(rock.hp == 0) {
          num next = Math.parseInt(rock.state.substring(4)) + 1;
          if(next > 10) {
            rocks.remove(key);
          }
          else {
            rock.state = "bomb$next";
          }
        }
        else {
          rock.state = rock.state.substring(0, 5);
          if(state == "gaming"
              && (x - rock.x).abs() < Config.cellWidth  * 0.7
              && (y - rock.y).abs() < Config.cellHeight * 0.7) {
            state = "dying";
            dying = 1;
          }
        }
      }
      else {
        rocks.remove(key);
      }
    }
  }


  void initialize() {
    for(num px = 0; px < Config.cols; ++px) {
      for(num py = 0; py < Config.rows + 1; ++py) {
        drawSpace(px, py);
      }
    }

    for(num i = 0; i < 3; ++i) {
      CanvasElement canvas = new Element.tag("canvas");
      canvas.width  = Config.cellWidth;
      canvas.height = Config.cellHeight;

      CanvasRenderingContext2D rctx = canvas.getContext("2d");
      rctx.drawImage(images["rock${i+1}"], 0, 0);
      rctx.globalCompositeOperation = "source-in";
      rctx.fillStyle = "#fff";
      rctx.fillRect(0, 0, canvas.width, canvas.height);
      images["rock${i+1}w"] = canvas;
    }

    currentTop = Config.height + Config.cellHeight;

    x =  Config.width >> 2;
    y = (Config.height * 3 / 4).toInt();
    frameCount = 0;
    score      = 0;

    bullets    = new Map<String, Bullet>();
    rocks      = new Map<String, Rock>();

    scoreElement.innerHTML = "000000000";

    state = "gaming";
    window.setTimeout( () => window.scrollTo(0, 0), 250 );
  }

  Status(String scoreboardName, String stageName) {
    // initialize properties
    state = "loading";

    imageName = <String>["my", "bullet", "rock1", "rock2", "rock3"];
    images    = new Map<String, Element>();

    Element scoreboard = document.query(scoreboardName);
    scoreboard.style.width = "${Config.width}px";
    scoreElement = scoreboard;

    CanvasElement stage = document.query(stageName);
    stage.width  = Config.width;
    stage.height = Config.height;
    ctx = stage.getContext("2d");

    CanvasElement bg = new Element.tag("canvas");
    bg.width  = Config.width;
    bg.height = Config.height + Config.cellHeight;
    bgCtx = bg.getContext("2d");

    for(num i = 0; i < 10; ++i) {
      imageName.add("space${i + 1}");
      imageName.add("bomb${i + 1}");
    }

    // preload
    num loadedCount = 0;
    void checkLoad(Event e) {
      if(++loadedCount == imageName.length) {
        initialize();
      }
    }
    for(final String name in imageName) {
      ImageElement image = new Element.tag("img");
      image.on.load.add(checkLoad);
      image.src = "img/${name}.png";
      images[name]  = image;
    }

    Point getPoint(UIEvent e) {
      num px;
      num py;
      if(e is TouchEvent) {
        TouchEvent te = e;
        px = te.touches[0].pageX;
        py = te.touches[0].pageY;
      }
      else {
        px = e.pageX;
        py = e.pageY;
      }
      return new Point(px, py);
    }

    void touchStart(UIEvent e) {
      e.preventDefault();
      final Point p = getPoint(e);

      lastX = p.x;
      lastY = p.y;

      if(state == "gameover") {
        initialize();
      }
    }
    document.body.on.mouseDown.add(touchStart);
    document.body.on.touchStart.add(touchStart);

    void touchMove(UIEvent e) {
      final Point p = getPoint(e);

      if(state == "gaming" && lastX != null) {
        x += ((p.x - lastX) * 2.5).toInt();
        y += ((p.y - lastY) * 3).toInt();

        x = Math.max(x, 0);
        x = Math.min(x, Config.width);

        y = Math.max(y, 0);
        y = Math.min(y, Config.height);
      }

      lastX = p.x;
      lastY = p.y;
    }
    document.body.on.mouseMove.add(touchMove);
    document.body.on.touchMove.add(touchMove);
  }
}

void main() {
  Status status = new Status("#scoreboard", "#stage");
  status.tick();
}
