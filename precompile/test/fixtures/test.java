public class Bicycle extends Ride implements Sweet {
  // the Bicycle class has
  // three fields
  public static int cadence;
  public int gear;
  public int speed;

  // the Bicycle class has
  // one constructor
  public Bicycle(int startCadence, int startSpeed, int startGear) {
    gear = startGear;
    cadence = startCadence;
    speed = startSpeed;
  }

  // the Bicycle class has
  // four methods
  public static void setCadence(int newValue) {
    cadence = newValue;
  }

  public void setGear(int newValue) {
    gear = newValue;
  }

  public void applyBrake(int decrement) {
    speed -= decrement;
  }

  public void speedUp(int increment) {
    speed += increment;
  }
}
