package ThorpeTubeFlowmeterModel {

    import ScalarValues::*;

    package CustomUnits {
        unit L_per_min;
        unit mm;
        unit mm2;
        unit N;
        unit kPa;
        unit g;
        unit kg_per_m3;
        unit m_per_s;
        unit deg;
        unit s;
    }

    package ValueTypes {
        import CustomUnits::*;

        value type VolumetricFlowRate :> Real { :>> unit = L_per_min; }
        value type Length :> Real { :>> unit = mm; }
        value type Area :> Real { :>> unit = mm2; }
        value type Force :> Real { :>> unit = N; }
        value type Pressure :> Real { :>> unit = kPa; }
        value type Mass :> Real { :>> unit = g; }
        value type Density :> Real { :>> unit = kg_per_m3; }
        value type Velocity :> Real { :>> unit = m_per_s; }
        value type Angle :> Real { :>> unit = deg; }
        value type Duration :> Real { :>> unit = s; }
        value type Fraction :> Real;
        value type Viscosity :> Real;
    }

    package Items {
        import ValueTypes::*;

        item def MedicalGas {
            attribute name : String;
            attribute density : Density;
            attribute dynamicViscosity : Viscosity;
        }

        item def Oxygen :> MedicalGas {
            :>> name = "Oxygen";
            :>> density = 1.429;
            :>> dynamicViscosity = 0.0000203;
        }

        item def NitrousOxide :> MedicalGas {
            :>> name = "Nitrous Oxide";
            :>> density = 1.978;
            :>> dynamicViscosity = 0.0000148;
        }

        item def MedicalAir :> MedicalGas {
            :>> name = "Medical Air";
            :>> density = 1.225;
            :>> dynamicViscosity = 0.0000183;
        }

        item def FloatBall {
            attribute material : String;
            attribute mass : Mass;
            attribute diameter : Length;
            attribute crossSectionArea : Area;
            attribute currentHeight : Length;
            attribute currentVelocity : Velocity;
            attribute currentAcceleration : Real;
        }
    }

    package Ports {
        import Items::*;
        import ValueTypes::*;

        port def GasFlowPort {
            in gas : MedicalGas;
            attribute pressure : Pressure;
            attribute flowRate : VolumetricFlowRate;
        }
    }

    package Calculations {
        import ValueTypes::*;
        import Items::*;

        calc def TubeDiameterAtHeight {
            in h : Length;
            in lowerDiameter : Length;
            in taperSlope : Real;
            return : Length = lowerDiameter + taperSlope * h;
        }

        calc def AnnularArea {
            in h : Length;
            in lowerDiameter : Length;
            in taperSlope : Real;
            in floatDiameter : Length;
            local tubeInnerDiameter : Length = lowerDiameter + taperSlope * h;
            return : Area = 3.14159265358979 / 4.0 * (tubeInnerDiameter * tubeInnerDiameter - floatDiameter * floatDiameter);
        }

        calc def DragForceOnFloat {
            in flowRate : VolumetricFlowRate;
            in annularArea : Area;
            in gasDensity : Density;
            in viscosity : Viscosity;
            local flowRateInM3PerSec : Real = flowRate / 60000.0;
            local areaInM2 : Real = annularArea / 1000000.0;
            local velocity : Real = flowRateInM3PerSec / areaInM2;
            local reynolds : Real = gasDensity * velocity * 0.0045 / viscosity;
            local dragCoeff : Real = 0.47;
            return : Real = 0.5 * gasDensity * velocity * velocity * areaInM2 * dragCoeff;
        }

        calc def GravityForceOnFloat {
            in floatMass : Mass;
            return : Real = floatMass / 1000.0 * 9.80665;
        }

        calc def BuoyancyForce {
            in floatVolume : Real;
            in gasDensity : Density;
            return : Real = gasDensity * floatVolume * 9.80665 / 1000000000.0;
        }

        calc def EffectiveWeight {
            in gravityForce : Real;
            in buoyancyForce : Real;
            return : Real = gravityForce - buoyancyForce;
        }

        calc def Flow2Height {
            in flowRate : VolumetricFlowRate;
            in maxFlow : VolumetricFlowRate;
            in tubeLength : Length;
            return : Length = flowRate / maxFlow * tubeLength;
        }

        calc def Height2Flow {
            in height : Length;
            in maxFlow : VolumetricFlowRate;
            in tubeLength : Length;
            return : VolumetricFlowRate = height / tubeLength * maxFlow;
        }
    }

    package Parts {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        import Calculations::*;

        part def TaperedGlassTube {
            attribute material : String = "Borosilicate Glass";
            attribute lowerDiameter : Length = 5.0;
            attribute upperDiameter : Length = 25.0;
            attribute tubeLength : Length = 150.0;
            attribute taperSlope : Real = 0.13333;
            attribute transparent : Boolean = true;
            attribute maxPressure : Pressure = 700.0;
            attribute wallThickness : Length = 1.5;

            port inlet : GasFlowPort;
            port outlet : GasFlowPort;

            attribute currentFlowRate : VolumetricFlowRate = 0.0;
            attribute currentPressure : Pressure = 0.0;
            attribute currentTemperature : Real = 21.0;

            calc diameterAt(h : Length) : Length = self.lowerDiameter + self.taperSlope * h;
            calc areaAt(h : Length) : Area = 3.14159265358979 / 4.0 * (self.diameterAt(h) * self.diameterAt(h));

            action updateFlowRate(flow : VolumetricFlowRate) {
                self.currentFlowRate = flow;
                self.inlet.flowRate = flow;
                self.outlet.flowRate = flow;
            }

            action updatePressure(pressure : Pressure) {
                self.currentPressure = pressure;
                self.inlet.pressure = pressure;
                self.outlet.pressure = pressure;
            }
        }

        part def Float {
            attribute floatMaterial : String = "Stainless Steel";
            attribute mass : Mass = 5.0;
            attribute diameter : Length = 4.5;
            attribute crossSectionArea : Area = 15.904;
            attribute currentHeight : Length = 0.0;
            attribute currentVelocity : Velocity = 0.0;
            attribute currentAcceleration : Real = 0.0;
            attribute minPosition : Length = 0.0;
            attribute maxPosition : Length = 145.0;
            attribute floatDensity : Density = 7850.0;

            action updatePosition(newHeight : Length, newVelocity : Velocity) {
                if (newHeight < self.minPosition) {
                    self.currentHeight = self.minPosition;
                } else if (newHeight > self.maxPosition) {
                    self.currentHeight = self.maxPosition;
                } else {
                    self.currentHeight = newHeight;
                }
                self.currentVelocity = newVelocity;
            }

            action reset() {
                self.currentHeight = 0.0;
                self.currentVelocity = 0.0;
                self.currentAcceleration = 0.0;
            }

            action raise(amount : Length) {
                if (self.currentHeight + amount <= self.maxPosition) {
                    self.currentHeight = self.currentHeight + amount;
                } else {
                    self.currentHeight = self.maxPosition;
                }
            }

            action lower(amount : Length) {
                if (self.currentHeight - amount >= self.minPosition) {
                    self.currentHeight = self.currentHeight - amount;
                } else {
                    self.currentHeight = self.minPosition;
                }
            }
        }

        part def ProtectiveHousing {
            attribute material : String = "Stainless Steel";
            attribute wallThickness : Length = 2.0;
            attribute maxWorkingPressure : Pressure = 600.0;
            attribute numVents : Integer = 4;
            attribute viewingWindow : Boolean = true;
            attribute windowMaterial : String = "Polycarbonate";
            attribute dropTestRating : Real = 1.5;
        }

        part def Scale {
            attribute minFlow : VolumetricFlowRate = 0.0;
            attribute maxFlow : VolumetricFlowRate = 50.0;
            attribute majorIncrement : VolumetricFlowRate = 5.0;
            attribute minorIncrement : VolumetricFlowRate = 1.0;
            attribute scaleLength : Length = 145.0;
            attribute calibrationFactor : Real = 0.345;
            attribute label : String = "O2 L/min";
            attribute scaleColor : String = "Black on White";

            action readFlowRate(height : Length) : VolumetricFlowRate {
                if (height <= 0.0) {
                    return 0.0;
                } else if (height >= self.scaleLength) {
                    return self.maxFlow;
                } else {
                    return height / self.scaleLength * self.maxFlow;
                }
            }

            action readFloatPosition(flow : VolumetricFlowRate) : Length {
                if (flow <= 0.0) {
                    return 0.0;
                } else if (flow >= self.maxFlow) {
                    return self.scaleLength;
                } else {
                    return flow / self.maxFlow * self.scaleLength;
                }
            }

            action applyCalibrationOffset(offset : Real) {
                self.calibrationFactor = self.calibrationFactor + offset;
            }
        }

        part def FlowControlValve {
            attribute valveType : String = "Needle Valve";
            attribute openingFraction : Fraction = 0.0;
            attribute maxFlow : VolumetricFlowRate = 50.0;
            attribute currentFlowRate : VolumetricFlowRate = 0.0;
            attribute knobTurns : Integer = 0;
            attribute maxKnobTurns : Integer = 5;
            attribute sealMaterial : String = "Viton";

            port inlet : GasFlowPort;
            port outlet : GasFlowPort;

            action adjustOpening(opening : Fraction) {
                if (opening < 0.0) {
                    self.openingFraction = 0.0;
                } else if (opening > 1.0) {
                    self.openingFraction = 1.0;
                } else {
                    self.openingFraction = opening;
                }
                self.currentFlowRate = self.openingFraction * self.maxFlow;
                self.knobTurns = (self.openingFraction * self.maxKnobTurns) as Integer;
            }

            action fullyOpen() {
                self.openingFraction = 1.0;
                self.currentFlowRate = self.maxFlow;
                self.knobTurns = self.maxKnobTurns;
            }

            action close() {
                self.openingFraction = 0.0;
                self.currentFlowRate = 0.0;
                self.knobTurns = 0;
            }

            action incrementTurn() {
                if (self.knobTurns < self.maxKnobTurns) {
                    self.knobTurns = self.knobTurns + 1;
                    self.openingFraction = self.knobTurns / self.maxKnobTurns;
                    self.currentFlowRate = self.openingFraction * self.maxFlow;
                }
            }

            action decrementTurn() {
                if (self.knobTurns > 0) {
                    self.knobTurns = self.knobTurns - 1;
                    self.openingFraction = self.knobTurns / self.maxKnobTurns;
                    self.currentFlowRate = self.openingFraction * self.maxFlow;
                }
            }

            action setFlowRate(targetFlow : VolumetricFlowRate) {
                if (targetFlow > self.maxFlow) {
                    self.fullyOpen();
                } else if (targetFlow <= 0.0) {
                    self.close();
                } else {
                    self.openingFraction = targetFlow / self.maxFlow;
                    self.currentFlowRate = targetFlow;
                    self.knobTurns = (self.openingFraction * self.maxKnobTurns) as Integer;
                }
            }
        }

        part def OrientationIndicator {
            attribute currentTilt : Angle = 0.0;
            attribute isVertical : Boolean = true;
            attribute tolerance : Angle = 5.0;
            attribute mountedOrientation : Angle = 90.0;
            attribute visualIndicator : String = "Spirit Level";

            action measure() {
                self.isVertical = (abs(self.currentTilt) < self.tolerance);
            }

            action setOrientation(tilt : Angle) {
                self.currentTilt = tilt;
                self.measure();
            }

            action resetToVertical() {
                self.currentTilt = 0.0;
                self.isVertical = true;
            }
        }

        part def ThorpeTubeFlowmeter {
            attribute manufacturer : String = "Medical Devices Inc.";
            attribute modelNumber : String = "TT-100";
            attribute requiredTilt : Angle = 90.0;
            attribute measurementRange : VolumetricFlowRate = 50.0;
            attribute maxOperatingPressure : Pressure = 400.0;
            attribute serialNumber : String = "TTF-2024-00123";
            attribute currentState : String = "noFlow";
            attribute lastOpeningFraction : Fraction = 0.0;
            attribute operatingMode : String = "Continuous";
            attribute certification : String = "ISO 80369";

            port inlet : GasFlowPort;
            port outlet : GasFlowPort;

            part housing : ProtectiveHousing;
            part glassTube : TaperedGlassTube;
            part float : Float;
            part scale : Scale;
            part controlValve : FlowControlValve;
            part orientation : OrientationIndicator;

            connection gasInletToValve connect inlet to controlValve.inlet;
            connection valveToTube connect controlValve.outlet to glassTube.inlet;
            connection tube2Outlet connect glassTube.outlet to outlet;

            action initialize() {
                self.currentState = "noFlow";
                self.float.reset();
                self.controlValve.close();
                self.orientation.measure();
            }

            action updateFlowRate(newFlow : VolumetricFlowRate) {
                self.glassTube.updateFlowRate(newFlow);
                self.controlValve.currentFlowRate = newFlow;
                self.inlet.flowRate = newFlow;
                self.glassTube.updatePressure(self.inlet.pressure);
            }

            action adjustFlow(opening : Fraction) {
                self.lastOpeningFraction = self.controlValve.openingFraction;
                self.controlValve.adjustOpening(opening);
                self.updateFlowRate(self.controlValve.currentFlowRate);
            }

            action setFlowRate(targetFlow : VolumetricFlowRate) {
                self.lastOpeningFraction = self.controlValve.openingFraction;
                self.controlValve.setFlowRate(targetFlow);
                self.updateFlowRate(self.controlValve.currentFlowRate);
            }

            action readCurrentFlow() : VolumetricFlowRate {
                return self.scale.readFlowRate(self.float.currentHeight);
            }

            action detectOverrange() : Boolean {
                return (self.glassTube.currentFlowRate > self.measurementRange);
            }

            action verifyOrientation() : Boolean {
                self.orientation.measure();
                return self.orientation.isVertical;
            }

            action shutdown() {
                self.controlValve.close();
                self.float.reset();
                self.currentState = "noFlow";
            }

            state flowStateMachine {
                state noFlow {
                    entry action {
                        self.currentState = "noFlow";
                        self.float.reset();
                    }
                }

                state rising {
                    entry action {
                        self.currentState = "rising";
                    }
                    do action {
                        local targetHeight : Length = self.scale.readFloatPosition(self.glassTube.currentFlowRate);
                        self.float.raise(targetHeight - self.float.currentHeight);
                    }
                    exit action {
                        self.float.currentVelocity = 0.0;
                    }
                }

                state steadyState {
                    entry action {
                        self.currentState = "steadyState";
                    }
                    do action {
                        self.float.currentVelocity = 0.0;
                    }
                }

                state overrange {
                    entry action {
                        self.currentState = "overrange";
                        self.float.updatePosition(self.float.maxPosition, 0.0);
                    }
                }

                transition initial to noFlow;

                transition from noFlow to rising
                    when self.inlet.flowRate > 0.0;

                transition from rising to steadyState
                    when abs(self.float.currentVelocity) < 0.001;

                transition from steadyState to rising
                    when abs(self.controlValve.openingFraction - self.lastOpeningFraction) > 0.01;

                transition from steadyState to overrange
                    when self.glassTube.currentFlowRate > self.measurementRange;

                transition from overrange to steadyState
                    when self.glassTube.currentFlowRate <= self.measurementRange;

                transition from overrange to noFlow
                    when self.glassTube.currentFlowRate <= 0.0;

                transition from steadyState to noFlow
                    when self.glassTube.currentFlowRate <= 0.0;
            }
        }
    }

    package Requirements {
        import Parts::*;
        import ValueTypes::*;

        requirement def ThorpeTubeFlowmeterRequirements {
            doc { The Thorpe tube flowmeter shall meet the operational requirements specified herein. }
            subject device : ThorpeTubeFlowmeter;
        }

        requirement VerticalOrientationRequirement :> ThorpeTubeFlowmeterRequirements {
            doc { The flowmeter must be mounted in a vertical orientation with tolerance of plus or minus five degrees for accurate operation. }
            subject device : ThorpeTubeFlowmeter;
            attribute tolerance : Angle = 5.0;
            requirement constraint {
                abs(device.orientation.currentTilt) < tolerance;
            }
        }

        requirement MeasurementAccuracyRequirement :> ThorpeTubeFlowmeterRequirements {
            doc { The flowmeter shall measure volumetric flow rate with an accuracy of plus or minus five percent of full scale reading. }
            subject device : ThorpeTubeFlowmeter;
            attribute fullScale : VolumetricFlowRate = 50.0;
            attribute accuracyTolerance : Fraction = 0.05;
            requirement constraint {
                abs(device.scale.readFlowRate(device.float.currentHeight) - device.glassTube.currentFlowRate)
                    <= accuracyTolerance * fullScale;
            }
        }

        requirement OverrangeIndicationRequirement :> ThorpeTubeFlowmeterRequirements {
            doc { The flowmeter shall indicate an overrange condition when the actual gas flow exceeds the maximum measurement range. }
            subject device : ThorpeTubeFlowmeter;
            requirement constraint {
                if (device.glassTube.currentFlowRate > device.measurementRange) {
                    device.float.currentHeight == device.float.maxPosition;
                }
            }
        }

        requirement HousingIntegrityRequirement :> ThorpeTubeFlowmeterRequirements {
            doc { The protective housing shall withstand pressures up to its maximum working pressure without failure. }
            subject device : ThorpeTubeFlowmeter;
            requirement constraint {
                device.housing.maxWorkingPressure > device.inlet.pressure;
            }
        }

        requirement FlowControlRangeRequirement :> ThorpeTubeFlowmeterRequirements {
            doc { The flow control valve shall allow adjustment of gas flow from zero to full measurement range. }
            subject device : ThorpeTubeFlowmeter;
            requirement constraint {
                0.0 <= device.controlValve.openingFraction <= 1.0;
            }
        }

        requirement TransparentTubeRequirement :> ThorpeTubeFlowmeterRequirements {
            doc { The tapered glass tube shall be transparent to allow direct visual observation of the float. }
            subject device : ThorpeTubeFlowmeter;
            requirement constraint {
                device.glassTube.transparent == true;
            }
        }

        requirement SteadyStateStabilityRequirement :> ThorpeTubeFlowmeterRequirements {
            doc { The flowmeter shall settle into a steady state where the float velocity approaches zero. }
            subject device : ThorpeTubeFlowmeter;
            attribute settlingTolerance : Velocity = 0.001;
            requirement constraint {
                abs(device.float.currentVelocity) < settlingTolerance;
            }
        }

        requirement CalibrationRequirement :> ThorpeTubeFlowmeterRequirements {
            doc { The flowmeter shall be calibrated such that the scale reading matches the actual flow rate at standard conditions. }
            subject device : ThorpeTubeFlowmeter;
            requirement constraint {
                device.scale.maxFlow == device.measurementRange;
            }
        }

        requirement TaperedTubeGeometryRequirement :> ThorpeTubeFlowmeterRequirements {
            doc { The glass tube shall be wider at the top than at the bottom to enable flow proportional height measurement. }
            subject device : ThorpeTubeFlowmeter;
            requirement constraint {
                device.glassTube.upperDiameter > device.glassTube.lowerDiameter;
            }
        }

        requirement MaxPressureOperationalRequirement :> ThorpeTubeFlowmeterRequirements {
            doc { The flowmeter shall withstand its maximum operating pressure without leakage or structural failure. }
            subject device : ThorpeTubeFlowmeter;
            requirement constraint {
                device.glassTube.maxPressure >= device.maxOperatingPressure;
                device.housing.maxWorkingPressure >= device.maxOperatingPressure;
            }
        }
    }

    package Tests {
        import Parts::*;
        import ValueTypes::*;
        import Items::*;

        action def FlowRateCalibrationTest {
            in subject device : ThorpeTubeFlowmeter;
            in testFlow : VolumetricFlowRate;
            in referenceGas : MedicalGas;
            attribute reading : VolumetricFlowRate;
            attribute passed : Boolean = true;
            attribute errorMargin : VolumetricFlowRate = 2.5;

            action run() {
                device.setFlowRate(testFlow);
                self.reading = device.readCurrentFlow();
                if (abs(self.reading - testFlow) > self.errorMargin) {
                    self.passed = false;
                }
            }
        }

        action def OrientationComplianceTest {
            in subject device : ThorpeTubeFlowmeter;
            in testTilt1 : Angle;
            in testTilt2 : Angle;
            in testTilt3 : Angle;
            attribute passed : Boolean = true;

            action run() {
                device.orientation.setOrientation(testTilt1);
                if (abs(testTilt1) >= 5.0 && device.orientation.isVertical) {
                    self.passed = false;
                }
                if (abs(testTilt1) < 5.0 && !device.orientation.isVertical) {
                    self.passed = false;
                }
                device.orientation.setOrientation(testTilt2);
                if (abs(testTilt2) >= 5.0 && device.orientation.isVertical) {
                    self.passed = false;
                }
                if (abs(testTilt2) < 5.0 && !device.orientation.isVertical) {
                    self.passed = false;
                }
                device.orientation.setOrientation(testTilt3);
                if (abs(testTilt3) >= 5.0 && device.orientation.isVertical) {
                    self.passed = false;
                }
                if (abs(testTilt3) < 5.0 && !device.orientation.isVertical) {
                    self.passed = false;
                }
            }
        }

        action def OverrangeTest {
            in subject device : ThorpeTubeFlowmeter;
            in testMaxFlow : VolumetricFlowRate = 60.0;
            attribute overrangeTriggered : Boolean = false;
            attribute passed : Boolean = true;

            action run() {
                device.updateFlowRate(testMaxFlow);
                if (device.detectOverrange()) {
                    self.overrangeTriggered = true;
                } else {
                    self.passed = false;
                }
            }
        }

        action def StateTransitionTest {
            in subject device : ThorpeTubeFlowmeter;
            attribute stateHistory1 : String;
            attribute stateHistory2 : String;
            attribute stateHistory3 : String;
            attribute passed : Boolean = true;

            action run() {
                device.initialize();
                self.stateHistory1 = device.currentState;
                device.adjustFlow(0.5);
                if (device.currentState != "rising") {
                    self.passed = false;
                }
                self.stateHistory2 = device.currentState;
                device.controlValve.close();
                self.stateHistory3 = device.currentState;
            }
        }

        action def PressureIntegrityTest {
            in subject device : ThorpeTubeFlowmeter;
            in testPressure : Pressure = 500.0;
            attribute passed : Boolean = true;

            action run() {
                device.glassTube.updatePressure(testPressure);
                if (device.glassTube.maxPressure < testPressure) {
                    self.passed = false;
                }
                if (device.housing.maxWorkingPressure < testPressure) {
                    self.passed = false;
                }
            }
        }
    }

    package Verification {
        import Requirements::*;
        import Tests::*;
        import Parts::*;

        verification VerticalOrientationVerification {
            subject req : VerticalOrientationRequirement;
            objective verify;
            method OrientationComplianceTest;
        }

        verification MeasurementAccuracyVerification {
            subject req : MeasurementAccuracyRequirement;
            objective verify;
            method FlowRateCalibrationTest;
        }

        verification OverrangeVerification {
            subject req : OverrangeIndicationRequirement;
            objective verify;
            method OverrangeTest;
        }

        verification HousingIntegrityVerification {
            subject req : HousingIntegrityRequirement;
            objective verify;
            method PressureIntegrityTest;
        }

        verification StateTransitionVerification {
            subject req : SteadyStateStabilityRequirement;
            objective verify;
            method StateTransitionTest;
        }
    }
}
