package PendulumClockSystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  quantity kind elapsedTime;
  quantity kind length;
  quantity kind angle;
  quantity kind angularSpeed;
  quantity kind mass;
  quantity kind force;
  quantity kind torque;
  quantity kind energy;
  quantity kind power;
  quantity kind rate;

  unit s {
    :>> symbol = "s";
    :>> quantityKind = elapsedTime;
  }

  unit min {
    :>> symbol = "min";
    :>> quantityKind = elapsedTime;
  }

  unit h {
    :>> symbol = "h";
    :>> quantityKind = elapsedTime;
  }

  unit m {
    :>> symbol = "m";
    :>> quantityKind = length;
  }

  unit kg {
    :>> symbol = "kg";
    :>> quantityKind = mass;
  }

  unit deg {
    :>> symbol = "deg";
    :>> quantityKind = angle;
  }

  unit rad {
    :>> symbol = "rad";
    :>> quantityKind = angle;
  }

  unit rpm {
    :>> symbol = "rpm";
    :>> quantityKind = angularSpeed;
  }

  unit N {
    :>> symbol = "N";
    :>> quantityKind = force;
  }

  unit Nm {
    :>> symbol = "N*m";
    :>> quantityKind = torque;
  }

  unit J {
    :>> symbol = "J";
    :>> quantityKind = energy;
  }

  unit W {
    :>> symbol = "W";
    :>> quantityKind = power;
  }

  unit ticksPerSecond {
    :>> symbol = "tick/s";
    :>> quantityKind = rate;
  }

  attribute def TimeValue :> Real {
    :>> unit = s;
  }

  attribute def LengthValue :> Real {
    :>> unit = m;
  }

  attribute def MassValue :> Real {
    :>> unit = kg;
  }

  attribute def AngleValue :> Real {
    :>> unit = deg;
  }

  attribute def AngularSpeedValue :> Real {
    :>> unit = rpm;
  }

  attribute def TorqueValue :> Real {
    :>> unit = Nm;
  }

  attribute def EnergyValue :> Real {
    :>> unit = J;
  }

  attribute def PowerValue :> Real {
    :>> unit = W;
  }

  attribute def TickRateValue :> Real {
    :>> unit = ticksPerSecond;
  }

  attribute def CountValue :> Integer;

  enum def ClockOperatingMode {
    enum stopped;
    enum winding;
    enum starting;
    enum regulating;
    enum displaying;
    enum chiming;
    enum lowEnergy;
    enum faulted;
  }

  enum def EscapementLockState {
    enum lockedOnEntryPallet;
    enum impulseDelivered;
    enum lockedOnExitPallet;
    enum released;
  }

  enum def ChimeMode {
    enum silent;
    enum hourStrike;
    enum halfHourStrike;
  }

  item def MechanicalEnergyPacket {
    attribute energy: EnergyValue;
    attribute deliveryDuration: TimeValue;
  }

  item def EscapementImpulse {
    attribute impulseTorque: TorqueValue;
    attribute impulseDuration: TimeValue;
    attribute impulseAngle: AngleValue;
  }

  item def PendulumPhase {
    attribute swingAngle: AngleValue;
    attribute angularSpeed: AngularSpeedValue;
    attribute crossingCenter: Boolean;
  }

  item def TimeTick {
    attribute tickIndex: CountValue;
    attribute intervalSincePreviousTick: TimeValue;
    attribute nominalInterval: TimeValue = 1.0;
  }

  item def ClockTime {
    attribute hours: Integer;
    attribute minutes: Integer;
    attribute seconds: Integer;
    attribute elapsedSinceSet: TimeValue;
  }

  item def AudibleStrike {
    attribute strikeCount: CountValue;
    attribute strikeInterval: TimeValue;
  }

  port def MechanicalPowerOutPort {
    out item energyPacket: MechanicalEnergyPacket;
    out torque: TorqueValue;
    out angularSpeed: AngularSpeedValue;
  }

  port def MechanicalPowerInPort {
    in item energyPacket: MechanicalEnergyPacket;
    in torque: TorqueValue;
    in angularSpeed: AngularSpeedValue;
  }

  port def EscapementImpulseOutPort {
    out item impulse: EscapementImpulse;
  }

  port def EscapementImpulseInPort {
    in item impulse: EscapementImpulse;
  }

  port def PendulumPhaseOutPort {
    out item phase: PendulumPhase;
  }

  port def PendulumPhaseInPort {
    in item phase: PendulumPhase;
  }

  port def TickOutPort {
    out item tick: TimeTick;
  }

  port def TickInPort {
    in item tick: TimeTick;
  }

  port def ClockTimeOutPort {
    out item indicatedTime: ClockTime;
  }

  port def ClockTimeInPort {
    in item indicatedTime: ClockTime;
  }

  port def ChimeCommandOutPort {
    out item strike: AudibleStrike;
  }

  port def ChimeCommandInPort {
    in item strike: AudibleStrike;
  }

  constraint def PendulumPeriodConstraint {
    in pendulumLength: LengthValue;
    in localGravity: Real;
    in period: TimeValue;
    constraint periodEquation {
      period == 2.0 * 3.141592653589793 * sqrt(pendulumLength / localGravity)
    }
  }

  constraint def TickRateConstraint {
    in pendulumPeriod: TimeValue;
    in tickRate: TickRateValue;
    constraint rateEquation {
      tickRate == 2.0 / pendulumPeriod
    }
  }

  constraint def TimeErrorConstraint {
    in indicatedElapsed: TimeValue;
    in referenceElapsed: TimeValue;
    in allowedError: TimeValue;
    constraint errorLimit {
      abs(indicatedElapsed - referenceElapsed) <= allowedError
    }
  }

  constraint def EnergyRunDurationConstraint {
    in storedEnergy: EnergyValue;
    in averagePowerConsumption: PowerValue;
    in runDuration: TimeValue;
    constraint durationEquation {
      runDuration == storedEnergy / averagePowerConsumption
    }
  }

  action def WindClock {
    in appliedEnergy: EnergyValue;
    out storedEnergy: EnergyValue;
    out mode: ClockOperatingMode;
    action liftWeight;
    action tensionCable;
    action latchRatchet;
    flow appliedEnergy to liftWeight;
    flow liftWeight to tensionCable;
    flow tensionCable to latchRatchet;
  }

  action def ReleaseStoredEnergy {
    in storedEnergy: EnergyValue;
    out controlledEnergyPacket: MechanicalEnergyPacket;
    out remainingEnergy: EnergyValue;
    action descendWeight;
    action rotateGreatWheel;
    action limitByEscapementLoad;
    flow storedEnergy to descendWeight;
    flow descendWeight to rotateGreatWheel;
    flow rotateGreatWheel to limitByEscapementLoad;
  }

  action def RegulateMotionByPendulum {
    in unregulatedEnergyPacket: MechanicalEnergyPacket;
    in pendulumPhase: PendulumPhase;
    out escapementImpulse: EscapementImpulse;
    out regulatedTick: TimeTick;
    action lockEscapeWheel;
    action releaseToothAtCenterCrossing;
    action deliverImpulseToPendulum;
    action countEscapeTooth;
    flow unregulatedEnergyPacket to lockEscapeWheel;
    flow pendulumPhase to releaseToothAtCenterCrossing;
    flow releaseToothAtCenterCrossing to deliverImpulseToPendulum;
    flow deliverImpulseToPendulum to countEscapeTooth;
  }

  action def AccumulateElapsedTime {
    in tick: TimeTick;
    in currentTime: ClockTime;
    out updatedTime: ClockTime;
    action validateTickInterval;
    action incrementSeconds;
    action rollMinutes;
    action rollHours;
    flow tick to validateTickInterval;
    flow validateTickInterval to incrementSeconds;
    flow incrementSeconds to rollMinutes;
    flow rollMinutes to rollHours;
  }

  action def DisplayClockTime {
    in indicatedTime: ClockTime;
    out hourHandAngle: AngleValue;
    out minuteHandAngle: AngleValue;
    out secondHandAngle: AngleValue;
    action positionSecondHand;
    action positionMinuteHand;
    action positionHourHand;
    flow indicatedTime to positionSecondHand;
    flow indicatedTime to positionMinuteHand;
    flow indicatedTime to positionHourHand;
  }

  action def StrikeHour {
    in indicatedTime: ClockTime;
    out strike: AudibleStrike;
    action computeStrikeCount;
    action liftHammer;
    action releaseHammer;
    flow indicatedTime to computeStrikeCount;
    flow computeStrikeCount to liftHammer;
    flow liftHammer to releaseHammer;
  }

  action def PrimaryFunction_Timekeeping {
    in woundEnergy: EnergyValue;
    in setTime: ClockTime;
    out displayedTime: ClockTime;
    action releaseEnergy: ReleaseStoredEnergy;
    action regulate: RegulateMotionByPendulum;
    action accumulate: AccumulateElapsedTime;
    action display: DisplayClockTime;
    flow woundEnergy to releaseEnergy.storedEnergy;
    flow releaseEnergy.controlledEnergyPacket to regulate.unregulatedEnergyPacket;
    flow regulate.regulatedTick to accumulate.tick;
    flow accumulate.updatedTime to display.indicatedTime;
    flow accumulate.updatedTime to displayedTime;
  }

  part def WeightDrive {
    attribute weightMass: MassValue = 4.5;
    attribute availableDrop: LengthValue = 1.2;
    attribute storedEnergy: EnergyValue = 52.9;
    attribute averageDeliveredPower: PowerValue = 0.00012;
    attribute nominalRunDuration: TimeValue = 441000.0;
    attribute ratchetLocked: Boolean = true;

    port driveOut: MechanicalPowerOutPort;

    perform action wind: WindClock;
    perform action release: ReleaseStoredEnergy;

    constraint runDuration: EnergyRunDurationConstraint {
      in storedEnergy = storedEnergy;
      in averagePowerConsumption = averageDeliveredPower;
      in runDuration = nominalRunDuration;
    }
  }

  part def GearWheel {
    attribute toothCount: CountValue;
    attribute pitchDiameter: LengthValue;
    attribute angularSpeed: AngularSpeedValue;
  }

  part def GearTrain {
    attribute greatWheelTeeth: CountValue = 96;
    attribute centerWheelTeeth: CountValue = 80;
    attribute thirdWheelTeeth: CountValue = 75;
    attribute escapeWheelTeeth: CountValue = 30;
    attribute totalRatioToMinuteHand: Real = 60.0;
    attribute totalRatioToEscapeWheel: Real = 4500.0;
    attribute transmittedTorque: TorqueValue = 0.012;

    part greatWheel: GearWheel {
      :>> toothCount = 96;
      :>> pitchDiameter = 0.080;
      :>> angularSpeed = 0.000694;
    }

    part centerWheel: GearWheel {
      :>> toothCount = 80;
      :>> pitchDiameter = 0.065;
      :>> angularSpeed = 0.041667;
    }

    part thirdWheel: GearWheel {
      :>> toothCount = 75;
      :>> pitchDiameter = 0.050;
      :>> angularSpeed = 2.5;
    }

    part escapeWheel: GearWheel {
      :>> toothCount = 30;
      :>> pitchDiameter = 0.035;
      :>> angularSpeed = 15.0;
    }

    port energyIn: MechanicalPowerInPort;
    port escapementDriveOut: MechanicalPowerOutPort;
    port minuteHandDriveOut: MechanicalPowerOutPort;
    port hourHandDriveOut: MechanicalPowerOutPort;

    connect energyIn to greatWheel;
    connect greatWheel to centerWheel;
    connect centerWheel to thirdWheel;
    connect thirdWheel to escapeWheel;
    connect escapeWheel to escapementDriveOut;
    connect centerWheel to minuteHandDriveOut;
    connect minuteHandDriveOut to hourHandDriveOut;
  }

  part def PendulumRod {
    attribute effectiveLength: LengthValue = 0.994;
    attribute thermalExpansionCompensated: Boolean = true;
  }

  part def PendulumBob {
    attribute bobMass: MassValue = 1.4;
    attribute adjustmentNutOffset: LengthValue = 0.0;
  }

  part def SuspensionSpring {
    attribute flexureLength: LengthValue = 0.030;
    attribute maximumSafeAngle: AngleValue = 6.0;
  }

  part def PendulumAssembly {
    attribute effectiveLength: LengthValue = 0.994;
    attribute localGravity: Real = 9.80665;
    attribute nominalPeriod: TimeValue = 2.0;
    attribute nominalTickInterval: TimeValue = 1.0;
    attribute swingAmplitude: AngleValue = 3.0;
    attribute dampingLossPerCycle: EnergyValue = 0.000002;
    attribute tickRate: TickRateValue = 1.0;

    part rod: PendulumRod;
    part bob: PendulumBob;
    part suspension: SuspensionSpring;

    port impulseIn: EscapementImpulseInPort;
    port phaseOut: PendulumPhaseOutPort;

    constraint periodConstraint: PendulumPeriodConstraint {
      in pendulumLength = effectiveLength;
      in localGravity = localGravity;
      in period = nominalPeriod;
    }

    constraint rateConstraint: TickRateConstraint {
      in pendulumPeriod = nominalPeriod;
      in tickRate = tickRate;
    }

    state pendulumMotion {
      entry; then atRest;

      state atRest;
      state swingingLeft;
      state crossingCenterLeftToRight;
      state swingingRight;
      state crossingCenterRightToLeft;
      state amplitudeLow;

      transition startSwing
        first atRest
        accept impulseIn.impulse
        then swingingLeft;

      transition leftCenterCrossing
        first swingingLeft
        if swingAmplitude >= 2.0
        then crossingCenterLeftToRight;

      transition completeRightSwing
        first crossingCenterLeftToRight
        then swingingRight;

      transition rightCenterCrossing
        first swingingRight
        if swingAmplitude >= 2.0
        then crossingCenterRightToLeft;

      transition completeLeftSwing
        first crossingCenterRightToLeft
        then swingingLeft;

      transition detectLowAmplitude
        first swingingLeft
        if swingAmplitude < 1.0
        then amplitudeLow;

      transition recoverAmplitude
        first amplitudeLow
        accept impulseIn.impulse
        then swingingLeft;
    }
  }

  part def Escapement {
    attribute escapeWheelToothCount: CountValue = 30;
    attribute impulseAngle: AngleValue = 1.5;
    attribute lockState: EscapementLockState = EscapementLockState::lockedOnEntryPallet;
    attribute nominalImpulseTorque: TorqueValue = 0.004;
    attribute nominalImpulseDuration: TimeValue = 0.08;

    port trainIn: MechanicalPowerInPort;
    port phaseIn: PendulumPhaseInPort;
    port impulseOut: EscapementImpulseOutPort;
    port tickOut: TickOutPort;

    perform action regulate: RegulateMotionByPendulum;

    state escapementCycle {
      entry; then entryLocked;

      state entryLocked;
      state entryRelease;
      state impulseOnEntryPallet;
      state exitLocked;
      state exitRelease;
      state impulseOnExitPallet;

      transition releaseEntry
        first entryLocked
        accept phaseIn.phase
        if phaseIn.phase.crossingCenter == true
        then entryRelease;

      transition impulseEntry
        first entryRelease
        then impulseOnEntryPallet;

      transition lockExit
        first impulseOnEntryPallet
        then exitLocked;

      transition releaseExit
        first exitLocked
        accept phaseIn.phase
        if phaseIn.phase.crossingCenter == true
        then exitRelease;

      transition impulseExit
        first exitRelease
        then impulseOnExitPallet;

      transition lockEntry
        first impulseOnExitPallet
        then entryLocked;
    }
  }

  part def TickCounter {
    attribute tickCount: CountValue = 0;
    attribute expectedTickInterval: TimeValue = 1.0;
    attribute accumulatedElapsedTime: TimeValue = 0.0;
    attribute missedTickDetected: Boolean = false;

    port tickIn: TickInPort;
    port timeOut: ClockTimeOutPort;

    perform action accumulate: AccumulateElapsedTime;
  }

  part def MotionWorks {
    attribute minuteToHourRatio: Real = 12.0;
    attribute secondHandRatio: Real = 60.0;
    attribute minuteHandAngle: AngleValue = 0.0;
    attribute hourHandAngle: AngleValue = 0.0;
    attribute secondHandAngle: AngleValue = 0.0;

    port timeIn: ClockTimeInPort;
    port secondDriveIn: MechanicalPowerInPort;
    port minuteDriveIn: MechanicalPowerInPort;
    port hourDriveIn: MechanicalPowerInPort;

    perform action display: DisplayClockTime;
  }

  part def DialAndHands {
    attribute dialDiameter: LengthValue = 0.280;
    attribute hourHandLength: LengthValue = 0.075;
    attribute minuteHandLength: LengthValue = 0.110;
    attribute secondHandLength: LengthValue = 0.120;
    attribute displayedHours: Integer = 12;
    attribute displayedMinutes: Integer = 0;
    attribute displayedSeconds: Integer = 0;

    port timeIn: ClockTimeInPort;
  }

  part def ChimeMechanism {
    attribute enabled: Boolean = true;
    attribute mode: ChimeMode = ChimeMode::silent;
    attribute hammerMass: MassValue = 0.050;
    attribute gongDiameter: LengthValue = 0.085;
    attribute nominalStrikeInterval: TimeValue = 1.5;

    port timeIn: ClockTimeInPort;
    port chimeCommandIn: ChimeCommandInPort;

    perform action strikeHour: StrikeHour;

    state chimeState {
      entry; then silent;

      state silent;
      state armedForHour;
      state strikingHour;
      state armedForHalfHour;
      state strikingHalfHour;

      transition armHour
        first silent
        accept timeIn.indicatedTime
        if timeIn.indicatedTime.minutes == 0 and timeIn.indicatedTime.seconds == 0
        then armedForHour;

      transition beginHourStrike
        first armedForHour
        then strikingHour;

      transition finishHourStrike
        first strikingHour
        then silent;

      transition armHalfHour
        first silent
        accept timeIn.indicatedTime
        if timeIn.indicatedTime.minutes == 30 and timeIn.indicatedTime.seconds == 0
        then armedForHalfHour;

      transition beginHalfHourStrike
        first armedForHalfHour
        then strikingHalfHour;

      transition finishHalfHourStrike
        first strikingHalfHour
        then silent;
    }
  }

  part def CaseAndFrame {
    attribute height: LengthValue = 1.85;
    attribute width: LengthValue = 0.42;
    attribute depth: LengthValue = 0.24;
    attribute pendulumClearance: LengthValue = 0.050;
    attribute protectsMovementFromDust: Boolean = true;
    attribute providesStableReference: Boolean = true;
  }

  part def PendulumClock {
    attribute mode: ClockOperatingMode = ClockOperatingMode::stopped;
    attribute allowedDailyError: TimeValue = 30.0;
    attribute nominalRunDuration: TimeValue = 604800.0;
    attribute referenceElapsedTime: TimeValue = 0.0;
    attribute indicatedElapsedTime: TimeValue = 0.0;
    attribute timeError: TimeValue = 0.0;

    part caseAndFrame: CaseAndFrame;
    part weightDrive: WeightDrive;
    part gearTrain: GearTrain;
    part escapement: Escapement;
    part pendulum: PendulumAssembly;
    part tickCounter: TickCounter;
    part motionWorks: MotionWorks;
    part dialAndHands: DialAndHands;
    part chimeMechanism: ChimeMechanism;

    port displayedTimeOut: ClockTimeOutPort;

    connect weightDrive.driveOut to gearTrain.energyIn;
    connect gearTrain.escapementDriveOut to escapement.trainIn;
    connect escapement.impulseOut to pendulum.impulseIn;
    connect pendulum.phaseOut to escapement.phaseIn;
    connect escapement.tickOut to tickCounter.tickIn;
    connect tickCounter.timeOut to motionWorks.timeIn;
    connect tickCounter.timeOut to dialAndHands.timeIn;
    connect tickCounter.timeOut to chimeMechanism.timeIn;
    connect tickCounter.timeOut to displayedTimeOut;
    connect gearTrain.minuteHandDriveOut to motionWorks.minuteDriveIn;
    connect gearTrain.hourHandDriveOut to motionWorks.hourDriveIn;

    perform action primaryFunction: PrimaryFunction_Timekeeping;

    constraint accuracy: TimeErrorConstraint {
      in indicatedElapsed = indicatedElapsedTime;
      in referenceElapsed = referenceElapsedTime;
      in allowedError = allowedDailyError;
    }

    state operatingLifecycle {
      entry; then stopped;

      state stopped;
      state winding;
      state starting;
      state regulating;
      state displaying;
      state chiming;
      state lowEnergy;
      state faulted;

      transition beginWinding
        first stopped
        then winding;

      transition finishWinding
        first winding
        if weightDrive.storedEnergy >= 45.0
        then starting;

      transition pendulumStarted
        first starting
        accept pendulum.phaseOut.phase
        then regulating;

      transition normalDisplay
        first regulating
        accept escapement.tickOut.tick
        then displaying;

      transition continueRegulation
        first displaying
        then regulating;

      transition beginChime
        first displaying
        accept chimeMechanism.chimeCommandIn.strike
        if chimeMechanism.enabled == true
        then chiming;

      transition chimeComplete
        first chiming
        then regulating;

      transition energyLow
        first regulating
        if weightDrive.storedEnergy < 5.0
        then lowEnergy;

      transition stopWhenUnwound
        first lowEnergy
        if weightDrive.storedEnergy <= 0.5
        then stopped;

      transition faultOnMissedTick
        first regulating
        if tickCounter.missedTickDetected == true
        then faulted;

      transition resetFault
        first faulted
        then stopped;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject clock: PendulumClock;
    doc /* The pendulum clock shall transform stored gravitational energy into regulated pendulum oscillations, count the resulting periodic ticks, and display elapsed civil time to a human observer. */
    require constraint primaryFunctionAvailable {
      clock.weightDrive.storedEnergy > 0.5 and
      clock.pendulum.nominalPeriod == 2.0 and
      clock.tickCounter.expectedTickInterval == 1.0
    }
  }

  requirement def PendulumRegulationRequirement {
    subject pendulum: PendulumAssembly;
    doc /* The pendulum assembly shall provide a stable reference period for the escapement so that two half-swings correspond to one nominal two-second cycle. */
    require constraint stablePeriod {
      abs(pendulum.nominalPeriod - 2.0) <= 0.02
    }
  }

  requirement def EscapementRequirement {
    subject escapement: Escapement;
    doc /* The escapement shall alternately lock and release the escape wheel, deliver impulse to the pendulum, and produce one tick for each center crossing. */
    require constraint impulseWithinSafeRange {
      escapement.nominalImpulseTorque > 0.001 and
      escapement.nominalImpulseTorque < 0.010 and
      escapement.nominalImpulseDuration <= 0.10
    }
  }

  requirement def DisplayRequirement {
    subject display: DialAndHands;
    doc /* The dial and hands shall present hours, minutes, and seconds derived from accumulated ticks. */
    require constraint readableGeometry {
      display.dialDiameter >= 0.200 and
      display.minuteHandLength < display.dialDiameter / 2.0 and
      display.hourHandLength < display.minuteHandLength
    }
  }

  requirement def AccuracyRequirement {
    subject clock: PendulumClock;
    doc /* The indicated elapsed time shall remain within thirty seconds of reference elapsed time over a twenty-four-hour operating interval when the clock is fully wound and level. */
    require constraint dailyAccuracy {
      abs(clock.indicatedElapsedTime - clock.referenceElapsedTime) <= clock.allowedDailyError
    }
  }

  requirement def RunDurationRequirement {
    subject clock: PendulumClock;
    doc /* The clock shall continue timekeeping for at least seven days after winding when the weight is raised to its normal starting height. */
    require constraint sevenDayRun {
      clock.nominalRunDuration >= 604800.0
    }
  }

  requirement def SafePendulumClearanceRequirement {
    subject clock: PendulumClock;
    doc /* The case shall provide sufficient clearance for normal pendulum amplitude without contact. */
    require constraint clearance {
      clock.caseAndFrame.pendulumClearance >= 0.030 and
      clock.pendulum.swingAmplitude <= 5.0
    }
  }

  requirement def ChimeRequirement {
    subject chime: ChimeMechanism;
    doc /* When enabled, the chime mechanism shall strike the current hour at the top of each hour and remain silent during normal timekeeping between chime events. */
    require constraint chimeTiming {
      chime.nominalStrikeInterval >= 1.0 and
      chime.nominalStrikeInterval <= 2.0
    }
  }

  requirement clockPrimaryFunction: PrimaryFunctionRequirement {
    subject clock = grandPendulumClock;
  }

  requirement clockAccuracy: AccuracyRequirement {
    subject clock = grandPendulumClock;
  }

  requirement clockRunDuration: RunDurationRequirement {
    subject clock = grandPendulumClock;
  }

  requirement clockClearance: SafePendulumClearanceRequirement {
    subject clock = grandPendulumClock;
  }

  part grandPendulumClock: PendulumClock {
    :>> allowedDailyError = 30.0;
    :>> nominalRunDuration = 604800.0;

    part :>> weightDrive {
      :>> weightMass = 4.5;
      :>> availableDrop = 1.2;
      :>> storedEnergy = 52.9;
      :>> averageDeliveredPower = 0.0000875;
      :>> nominalRunDuration = 604800.0;
    }

    part :>> pendulum {
      :>> effectiveLength = 0.994;
      :>> nominalPeriod = 2.0;
      :>> nominalTickInterval = 1.0;
      :>> swingAmplitude = 3.0;
    }

    part :>> dialAndHands {
      :>> dialDiameter = 0.280;
      :>> hourHandLength = 0.075;
      :>> minuteHandLength = 0.110;
      :>> secondHandLength = 0.120;
    }

    part :>> chimeMechanism {
      :>> enabled = true;
      :>> nominalStrikeInterval = 1.5;
    }
  }

}
