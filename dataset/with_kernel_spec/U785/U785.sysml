package NicholsRadiometerModel {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::Real;
    private import ISQ::AngleValue;
    private import ISQ::AreaValue;
    private import ISQ::LengthValue;
    private import ISQ::PressureValue;
    private import ISQ::ForceValue;
    private import ISQ::PowerValue;

    package Definitions {
        attribute def LightBeam {
            attribute power : PowerValue;
            attribute wavelength : LengthValue;
        }
        attribute def LightOnSignal;
        attribute def LightOffSignal;

        port def LightPort {
            in light : LightBeam;
        }
        
        port def PressurePort {
            out pressure : PressureValue;
        }

        part def TorsionFiber {
            attribute torsionConstant : Real = 1e-9;
            attribute length : LengthValue = 0.1 [m];
        }

        part def Mirror {
            attribute area : AreaValue = 1e-4 [m^2];
            attribute reflectivity : Real = 0.95;
            attribute leverArm : LengthValue = 0.05 [m];
            attribute deflectionAngle : AngleValue = 0 [rad];
        }

        part def SuspensionAssembly {
            part torsionFiber : TorsionFiber;
            part mirror : Mirror;
        }

        part def VacuumChamber {
            attribute pressure : PressureValue = 1e-6 [Pa];
            part suspension : SuspensionAssembly;
        }

        part def OpticalLever {
            attribute amplificationFactor : Real = 1000;
            attribute measuredAngle : AngleValue = 0 [rad];
        }

        action def 'Apply Radiation Force' {
            in lightBeam : LightBeam;
            in mirrorArea : AreaValue;
            in reflectivity : Real;
            out radiationForce : ForceValue;
        }

        action def 'Twist Mirror' {
            in radiationForce : ForceValue;
            in leverArm : LengthValue;
            in torsionConstant : Real;
            out deflectionAngle : AngleValue;
        }

        action def 'Amplify Deflection' {
            in deflectionAngle : AngleValue;
            in amplificationFactor : Real;
            out measuredAngle : AngleValue;
        }

        action def 'Calculate Pressure' {
            in measuredAngle : AngleValue;
            in amplificationFactor : Real;
            in torsionConstant : Real;
            in leverArm : LengthValue;
            in mirrorArea : AreaValue;
            out radiationPressure : PressureValue;
        }

        action def 'Measure Radiation Pressure' {
            in lightBeam : LightBeam;
            in mirrorArea : AreaValue;
            in reflectivity : Real;
            in leverArm : LengthValue;
            in torsionConstant : Real;
            in amplificationFactor : Real;
            out radiationPressure : PressureValue;

            action applyRadiationForce : 'Apply Radiation Force' {
                in lightBeam = lightBeam;
                in mirrorArea = mirrorArea;
                in reflectivity = reflectivity;
                out radiationForce : ForceValue;
            }
            action twistMirror : 'Twist Mirror' {
                in radiationForce : ForceValue;
                in leverArm = leverArm;
                in torsionConstant = torsionConstant;
                out deflectionAngle : AngleValue;
            }
            action amplifyDeflection : 'Amplify Deflection' {
                in deflectionAngle : AngleValue;
                in amplificationFactor = amplificationFactor;
                out measuredAngle : AngleValue;
            }
            action calculatePressure : 'Calculate Pressure' {
                in measuredAngle : AngleValue;
                in amplificationFactor = amplificationFactor;
                in torsionConstant = torsionConstant;
                in leverArm = leverArm;
                in mirrorArea = mirrorArea;
                out radiationPressure : PressureValue;
            }

            flow applyRadiationForce.radiationForce to twistMirror.radiationForce;
            flow twistMirror.deflectionAngle to amplifyDeflection.deflectionAngle;
            flow amplifyDeflection.measuredAngle to calculatePressure.measuredAngle;
        }

        part def NicholsRadiometer {
            part vacuumChamber : VacuumChamber;
            part opticalLever : OpticalLever;
            port lightPort : LightPort;
            port pressureOut : PressurePort;

            action measureRadiationPressure : 'Measure Radiation Pressure' {
                in lightBeam = lightPort.light;
                in mirrorArea = vacuumChamber.suspension.mirror.area;
                in reflectivity = vacuumChamber.suspension.mirror.reflectivity;
                in leverArm = vacuumChamber.suspension.mirror.leverArm;
                in torsionConstant = vacuumChamber.suspension.torsionFiber.torsionConstant;
                in amplificationFactor = opticalLever.amplificationFactor;
                out radiationPressure = pressureOut.pressure;
            }

            state machine {
                initial;
                transition first initial then idle;
                state idle;
                state measuring {
                    entry perform measureRadiationPressure;
                }
                transition first idle accept LightOnSignal then measuring;
                transition first measuring accept LightOffSignal then idle;
            }
        }
        
        requirement def 'Measure Radiation Pressure Requirement' {
            doc /* The Nichols radiometer shall measure the pressure exerted by electromagnetic radiation using a suspended mirror and optical lever. */
        }
    }

    package Usages {
        private import Definitions::*;
        part nicholsRadiometer : NicholsRadiometer {
            satisfy 'Measure Radiation Pressure Requirement';
        }
    }
}
