import "dart:html";
import "dart:math";
import "dart:web_audio";

class Game {
  CanvasElement            canvas;
  CanvasRenderingContext2D screen;
  Map<String, int>         size;
  List<Body>               bodies;

  Game(String id) {
    canvas = querySelector(id);
    screen = canvas.getContext("2d");
    size   = {"width": canvas.width, "height": canvas.height};
    bodies =
      Invader.createInvaders(this)
        ..add(new Player(this, size));
  }

  void tick([num delta]) {
    update();
    draw();
    window.animationFrame.then(tick);
  }

  void update() {
    bodies = bodies.where(
        (body1) => !bodies.any(
            (body2) => Body.areColliding(body1, body2)
        )
    ).toList();

    for (var i = 0; i < bodies.length; i++) {
      bodies[i].update();
    }
  }

  void draw() {
    screen.clearRect(0, 0, size["width"], size["height"]);
    for (var body in bodies) {
      body.draw(screen);
    }
  }

  void addBody(body) {
    bodies.add(body);
  }
}

class Sound {
  AudioContext audio;
  AudioBuffer  buffer;

  Sound(String url, Function afterLoad) {
    audio = new AudioContext();

    var request = new HttpRequest();
    request.open("GET", url);
    request.responseType = "arraybuffer";
    request.onLoad.listen( (event) {
      audio.decodeAudioData(event.target.response).then( (b) {
        buffer = b;
        afterLoad(this);
      } );
    } );
    request.send();
  }

  void play() {
    var source = audio.createBufferSource();
    source.buffer = buffer;
    source.connectNode(audio.destination);
    source.start(0);
  }
}

class Keyboarder {
  static final Map<String, int> keys = {"left": 37, "right": 39, "space": 32};

  Map<int, bool> keyStates;

  Keyboarder() {
    keyStates = { };

    window.onKeyDown.listen( (e) => keyStates[e.keyCode] = true  );
    window.onKeyUp.listen(   (e) => keyStates[e.keyCode] = false );
  }

  bool isDown(keyCode) => keyStates[keyCode];
}

abstract class Body {
  Map<String, int>    size;
  Map<String, double> center;

  static bool areColliding(body1, body2) {
    return !(
        body1 == body2                                  ||
        body1.center["x"] + body1.size["width"] / 2 <
            body2.center["x"] - body2.size["width"] / 2 ||
        body1.center["y"] + body1.size["height"] / 2 <
            body2.center["y"] - body2.size["height"] / 2 ||
        body1.center["x"] - body1.size["width"] / 2 >
            body2.center["x"] + body2.size["width"] / 2 ||
        body1.center["y"] - body1.size["height"] / 2 >
            body2.center["y"] + body2.size["height"] / 2
    );
  }

  void update();

  void draw(screen) {
    screen.fillRect( center["x"] - size["width"]  / 2,
                     center["y"] - size["height"] / 2,
                     size["width"],
                     size["height"] );
  }
}

class Player extends Body {
  Game       game;
  Keyboarder keyboader;

  Player(this.game, gameSize) {
    size      = {"width": 15, "height": 15};
    center    = { "x": gameSize["width"] / 2,
                  "y": gameSize["height"] - size["height"] };
    keyboader = new Keyboarder();
  }

  void update() {
    if (keyboader.isDown(Keyboarder.keys["left"])) {
      center["x"] -= 2;
    } else if (keyboader.isDown(Keyboarder.keys["right"])) {
      center["x"] += 2;
    }

    if (keyboader.isDown(Keyboarder.keys["space"])) {
      var bullet = new Bullet(
          {"x": center["x"], "y": center["y"] - size["height"] / 2},
          {"x": 0,           "y": -6}
      );
      game.addBody(bullet);
    }
  }
}

class Bullet extends Body {
  static Sound sound;

  Map<String, int> velocity;

  Bullet(center, velocity) {
    this.center   = center;
    this.velocity = velocity;
    size          = {"width": 3, "height": 3};

    sound.play();
  }

  void update() {
    center["x"] += velocity["x"];
    center["y"] += velocity["y"];
  }
}

class Invader extends Body {
  static Random rng = new Random();

  Game   game;
  double patrolX;
  double speedX;

  static List<Body> createInvaders(game) {
    var invaders = new List<Body>();
    for (var x = 0; x < 8; x++) {
      for (var y = 0; y < 3; y++) {
        invaders.add(new Invader(game, {"x": 30 + x * 30, "y": 30 + y * 30}));
      }
    }
    return invaders;
  }

  Invader(this.game, center) {
    this.center = center;
    size        = {"width": 15, "height": 15};
    patrolX     = 0.0;
    speedX      = 0.3;
  }

  void update() {
    if (patrolX < 0 || patrolX > 40) {
      speedX = -speedX;
    }

    center["x"] += speedX;
    patrolX     += speedX;

    if (rng.nextDouble() > 0.995 && !hasInvaderBelow()) {
      var bullet = new Bullet(
          {"x": center["x"],            "y": center["y"] + size["height"] / 2},
          {"x": rng.nextDouble() - 0.5, "y": 2}
      );
      game.addBody(bullet);
    }
  }

  bool hasInvaderBelow() {
    return game.bodies.any(
        (body) => body is Invader                                     &&
                  body.center["x"] - this.center["x"] < size["width"] &&
                  body.center["y"] > this.center["y"]
    );
  }
}

void main() {
  var game  = new Game("#screen");
  var sound = new Sound( "http://localhost:8080/laser.mp3", (s) {
    Bullet.sound = s;
    game.tick();
  } );
}
