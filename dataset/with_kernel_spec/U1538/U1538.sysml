package 'Aircraft Wing System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    public import 'Wing Definitions'::*;
    
    package 'Wing Definitions' {
        part def Spar {
            attribute material : String;
        }
        part def Rib {
            attribute material : String;
        }
        part def Skin {
            attribute material : String;
            attribute thickness : LengthValue;
        }
        part def Aileron {
            attribute deflection : Real;
            port ctrl : ControlSurfaceCommandPort;
        }
        part def Flap {
            attribute extension : Real;
            port ctrl : ControlSurfaceCommandPort;
        }
        part def Wing {
            attribute span : LengthValue;
            attribute sweepAngle : Real;
            attribute dihedralAngle : Real;
            attribute material : String;
            attribute referenceArea : AreaValue;
            attribute criticalAngleOfAttack : Real;
            attribute liftCoefficient : Real;
            attribute dragCoefficient : Real;
            
            part frontSpar : Spar;
            part rearSpar : Spar;
            part ribs : Rib[24];
            part upperSkin : Skin;
            part lowerSkin : Skin;
            
            part leftAileron : Aileron;
            part rightAileron : Aileron;
            part flaps : Flap;
            
            port airflowPort : AirflowPort;
            port leftAileronControl : ControlSurfaceCommandPort;
            port rightAileronControl : ControlSurfaceCommandPort;
            port flapControl : ControlSurfaceCommandPort;
            port forcePort : ForcePort;
            
            exhibit state 'wing states' : 'Wing States';
        }
        port def AirflowPort {
            attribute velocity : SpeedValue;
            attribute pressure : PressureValue;
            attribute density : MassDensityValue;
            attribute angleOfAttack : Real;
        }
        port def ControlSurfaceCommandPort {
            attribute commandedDeflection : Real;
        }
        port def ForcePort {
            attribute lift : ForceValue;
            attribute drag : ForceValue;
        }
        action def 'Sense Airflow' {
            out velocity : SpeedValue;
            out pressure : PressureValue;
            out density : MassDensityValue;
            out angleOfAttack : Real;
        }
        action def 'Calculate Aerodynamic Forces' {
            in rho : MassDensityValue;
            in v : SpeedValue;
            in area : AreaValue;
            in alpha : Real;
            in Cl : Real;
            in Cd : Real;
            out lift : ForceValue;
            out drag : ForceValue;
        }
        state def 'Wing States';
    }
    
    package 'Aerodynamic Functions' {
        private import ISQ::*;
        private import ScalarValues::*;
        calc def 'Lift Equation' {
            in rho : MassDensityValue;
            in v : SpeedValue;
            in area : AreaValue;
            in Cl : Real;
            return lift : ForceValue = 0.5 * rho * v^2 * area * Cl;
        }
        calc def 'Drag Equation' {
            in rho : MassDensityValue;
            in v : SpeedValue;
            in area : AreaValue;
            in Cd : Real;
            return drag : ForceValue = 0.5 * rho * v^2 * area * Cd;
        }
    }
    
    package 'Wing Usages' {
        private import 'Wing Definitions'::*;
        private import 'Aerodynamic Functions'::*;
        
        part wing1 : Wing {
            attribute :>> span = 12 [m];
            attribute :>> sweepAngle = 25;
            attribute :>> dihedralAngle = 5;
            attribute :>> material = "Aluminum";
            attribute :>> referenceArea = 25 [m^2];
            attribute :>> criticalAngleOfAttack = 15;
            attribute :>> liftCoefficient = 1.2;
            attribute :>> dragCoefficient = 0.08;
            
            part frontSpar : Spar {
                attribute :>> material = "Aluminum";
            }
            part rearSpar : Spar {
                attribute :>> material = "Aluminum";
            }
            part ribs : Rib[24] {
                attribute :>> material = "Aluminum";
            }
            part upperSkin : Skin {
                attribute :>> thickness = 0.002 [m];
                attribute :>> material = "Aluminum";
            }
            part lowerSkin : Skin {
                attribute :>> thickness = 0.002 [m];
                attribute :>> material = "Aluminum";
            }
            
            part leftAileron : Aileron;
            part rightAileron : Aileron;
            part flaps : Flap;
            
            connect leftAileronControl to leftAileron.ctrl;
            connect rightAileronControl to rightAileron.ctrl;
            connect flapControl to flaps.ctrl;
            
            bind leftAileron.deflection = leftAileronControl.commandedDeflection;
            bind rightAileron.deflection = rightAileronControl.commandedDeflection;
            bind flaps.extension = flapControl.commandedDeflection;
            
            action 'sense airflow' : 'Sense Airflow';
            action 'calculate forces' : 'Calculate Aerodynamic Forces' {
                in rho = airflowPort.density;
                in v = airflowPort.velocity;
                in area = referenceArea;
                in alpha = airflowPort.angleOfAttack;
                in Cl = liftCoefficient;
                in Cd = dragCoefficient;
                out lift = forcePort.lift;
                out drag = forcePort.drag;
            }
            
            exhibit state 'wing states' : 'Wing States' {
                entry; then idle;
                do 'sense airflow';
                
                state idle;
                accept when airflowPort.velocity > 25 [m/s]
                    then generatingLift;
                
                state generatingLift {
                    do 'calculate forces';
                }
                accept when leftAileron.deflection != 0 or rightAileron.deflection != 0 or flaps.extension != 0
                    then maneuvering;
                accept when airflowPort.angleOfAttack > criticalAngleOfAttack
                    then stalled;
                
                state maneuvering {
                    do 'calculate forces';
                }
                accept when leftAileron.deflection == 0 and rightAileron.deflection == 0 and flaps.extension == 0
                    then generatingLift;
                accept when airflowPort.angleOfAttack > criticalAngleOfAttack
                    then stalled;
                
                state stalled;
                accept when airflowPort.angleOfAttack <= criticalAngleOfAttack and airflowPort.velocity > 25 [m/s]
                    then generatingLift;
            }
        }
    }
    
    package 'Wing Requirements' {
        private import 'Wing Definitions'::*;
        private import 'Wing Usages'::*;
        
        requirement def <'1'> 'Lift Generation Requirement' {
            doc /* The wing shall generate sufficient lift to keep the aircraft airborne. */
            attribute requiredLift : ForceValue;
            attribute actualLift : ForceValue;
            require constraint { actualLift >= requiredLift }
        }
        
        requirement def <'2'> 'Control Surface Requirement' {
            doc /* The wing shall provide roll control via ailerons and increased lift via flaps. */
        }
        
        requirement def <'3'> 'Stall Prevention Requirement' {
            doc /* The wing shall avoid exceeding the critical angle of attack. */
            attribute criticalAoA : Real;
            attribute currentAoA : Real;
            require constraint { currentAoA < criticalAoA }
        }
        
        requirement <'1.1'> wingLiftReq : 'Lift Generation Requirement' {
            subject wing : Wing;
            attribute :>> requiredLift = 50000 [N];
            attribute :>> actualLift = wing.forcePort.lift;
        }
        
        requirement <'2.1'> wingControlReq : 'Control Surface Requirement' {
            subject wing : Wing;
        }
        
        requirement <'3.1'> wingStallReq : 'Stall Prevention Requirement' {
            subject wing : Wing;
            attribute :>> criticalAoA = wing.criticalAngleOfAttack;
            attribute :>> currentAoA = wing.airflowPort.angleOfAttack;
        }
    }
}
