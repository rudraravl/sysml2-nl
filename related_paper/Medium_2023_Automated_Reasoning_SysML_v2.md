Sidebar menu

Write
Notifications

Creatixchu
Home
Library
Profile
Stories
Stats
Following
Benedict Neo
Benedict Neo
Kai Bu
Kai Bu
Find writers and publications to follow.
See suggestions
Get unlimited access to the best of Medium for less than $1/week.
Become a member

Imandra Inc.
Automated Reasoning for SysML v2

Jamie Smith
Jamie Smith

Follow
14 min read
·
Aug 6, 2023
177

1




Press enter or click to view image in full size

Version 2 of SysML represents a significant advance over version 1 and is aimed to address numerous shortcomings and limitations of applicability to many types of modern systems engineering challenges (see this for example). Unlike v1, which was based on UML, v2 is based on KerML, a modeling language with formal semantics. It is this foundation of v2 that paves way to applying the latest advances in automated reasoning to empower SysML v2 users with rigorous analysis (including formal verification) of their models, AI-powered testing, integration with LLMs (e.g. ChatGPT) and much more.
I am excited to share some of the work we have been doing over the last several weeks on integrating our reasoning engine, Imandra, with the SysML v2 pilot implementation. Our initial focus is on creating an automated translation process between SysML v2 and Imandra Modeling Language (IML), and then using Imandra to reason about the resulting IML models.
In this article, we’ll cover an example of a traffic light model and verify some of its properties:
1. The behavior is deterministic, regardless of state or parameter values.
2. Errors are handled properly, irrespective of state or parameter values.
3. The light only switches to green when it is safe (all other lights in the system are red), irrespective of state or parameter values.
SysML v2 will empower the next step in MBSE evolution
Increasing system complexity is driving a fundamental shift from document-based systems engineering to model-based systems engineering (MBSE) and sophisticated model-based systems engineering tools. While MBSE has its roots in the aerospace and defense industries, we see MBSE gaining popularity across all sectors. Systems Modeling Language or SysML has been closely linked with MBSE since the first version of the standard was published by the Object Management Group (OMG) in 2006. SysML provides a standard graphical format to model complex systems’ requirements, architecture, and design and has been adopted by most systems design tools. SysML has helped teams share and communicate their designs with collaborators and customers during the design process.
The OMG is taking MBSE to the next stage in its evolution. At the Q2 2023 OMG members’ meeting, the SysML steering committee shared their plans for SysML v2 during a hybrid webinar hosted in Orlando, FL. Check out their video for a great overview.
The team, comprised of representatives from over 50 organizations, has leveraged 15 years of learning to define SysML v2. SysML v2 will enable increased precision, usability, and interoperability and allow the next generation of systems engineers and the next generation of systems.
While SysML v1 was based on UML, SysML v2 was built on Kernel Modeling Language (KerML). KerML is designed to be extensible and with formal semantics. Formal semantics brings mathematical precision to enable rigorous analysis and verification. We have begun leveraging the formalism of SysML v2 to analyze designs with Imandra. With Imandra, we can reason about the design to determine whether it will meet the desired requirements. We can also mathematically prove that its behavior is correct and safe by using formal verification techniques. To illustrate what we can accomplish, let’s review a system design we recently created for a simple traffic light.
We created this traffic light design with the SysML v2 pilot implementation in a Jupyter Labs development environment. The SysML v2 pilot implementation is freely available and can be found here. https://github.com/Systems-Modeling/SysML-v2-Pilot-Implementation
The SysML v2 Traffic Light Model
The SysML v2 traffic light model is based on standard green, yellow, and red traffic lights used in the United States. We chose the traffic light because it is complicated enough to demonstrate some key capabilities of both SysML v2 and Imandra while not being so complex that it would be difficult to understand. The complete SysML v2 model is available at the end of this blog post in Appendix A.
The model is contained in one package and includes 7 parts, 5 ports, 2 interfaces, 16 actions, and 12 states. Review the SysML v2 overview video linked above if these terms are new to you. We have also created an equivalent version of this model in IML to allow us to analyze the system’s behavior and verify properties.
We use Imandra to verify the behavior of the Traffic Light and uncover errors in the states and state transitions. Below is the SysML v2 state diagram, which is a graphical representation of the behavior of the traffic light. Let’s walk through it.
The traffic light starts in the “off” state, and once it receives power, it will enter the “init” state. During the “init” state, a power-up test is run, and if the outcome of that test returns an error; the traffic light will enter “diagnostic,” where additional tests will be run, and the error status will be communicated wirelessly to operators. Then the traffic light advances to “red_blinking” and operates as a stop sign until a technician can correct the error. If the power test returns no error, the light is ready to enter one of its three operational modes: “traffic_flow,” “caution,” or “stop_sign.” A collection of states, actions, and transitions dictates the behavior of the light.
Press enter or click to view image in full size

Here are some examples of the SysML v2 for states and their equivalents in IML. Each state has a name and perhaps a series of actions. The actions are classified as entry, then, do, or exit. When the system enters the state, you perform the “entry action,” followed by the “then actions” and then the “do action.” The “do action” is executed until the state is exited. When the system exits a state, it performs the “exit action.”
The code snippets below show that both the SysML v2 and the IML contain the same state names and corresponding actions.
SysML v2 states
IML equivalent states
We have created equivalent data types of all the elements in SysML v2 in IML. Let’s take a look at transitions.
SysML v2 Transition Usages:
IML equivalent transitions:
Each transition has an initial state and a subsequent state, along with a Boolean expression to determine if the transition is valid. For example, look at the transition from “init_to_operation_selection.”
first state = “init”
Boolean expression “error = false”
Next state = “operation_selection”
So, if we are in the “init” state and the error is false, we move to the “operation_selection” state.
Finally, look at the actions in both SysML v2 and IML syntax.
SysML v2 actions
IML equivalent actions
These action functions, include, but are not limited to, turning the lights on and off, managing errors, and reading sensors and clocks.
Verification of the Traffic Light
As I mentioned above, we used Imandra to verify three properties of the traffic light.
1. The behavior is deterministic, regardless of state or parameter values.
2. Errors are handled properly, irrespective of state or parameter values.
3. The light only switches to green when it is safe (all other lights in the system are red), regardless of state or parameter values.
We will take a deeper look at verification goal number two, verifying that errors are correctly handled. You can explore the notebook to learn more about the other two verification goals.
The collection of the state, actions, and transition functions dictate the behavior of the traffic light. We used the IML data types for each of those, along with attributes, to explore and verify the behavior of the traffic light. In practice, we created a data type that included the SysML_states AND the relevant attributes.
The attributes are listed here:
We combined those attributes with the SysML_state. The SysML_states are the 12 states shown in the state diagram above: off, init, diagnostic, operation_selection, stop_sign, caution, traffic_flow, red_blinking, yellow_blinking, green_on, yellow_on, and red_on. Into a single type called `sysml_state_attributes’:
In our IML model, we declared a variable called ‘sa’ of type sysml_state_attributes to represent the larger state of the traffic light. We use this data type along with the transition functions and actions to determine the behavior of the traffic light. We define a function called “my_step” that, when called, does five things.
1. Increments the system clock by 1 second.
2. Runs any “do action” for the current SysML_state
3. Checks the transition functions to see if the SysML_state should change
4. If the SysML_state changes (a. it runs the “exit action” of the current SysML_state, b. it runs the “entry action,” “do action,” and “then actions” of the new SysML_state)
5. Returns a variable of type “sysml_state_attributes.”
Here is “my_step” written in IML.
We use the function “my_step” and the variable “sa” along with Imandra Automated Reasoning to verify the behavior of the traffic light. You may have noticed another parameter called “ex_m:external_messages.”
External_messages include the incoming control messages and health information about the system. You can think of this as the information external to the traffic light controller that must be received, measured, and evaluated to determine SysML_state transitions.
Imandra has an internal function called “verify” that evaluates a Boolean function and either returns Proved.
Confirming that the Boolean function is always true for all variables and parameters or it returns Refuted.
If “verify” returns refuted, it includes a counter-examples that provides a set of parameters resulting in the Boolean function being false. This is incredibly powerful and saves hours or days of debugging and attempting to find the conditions that caused your verification goal to fail.
For our traffic light example, we designed our system such that if an error occurs, the system will transition SysML_states moving SysML_state to SysML_state until it reaches “diagnostic” and then “red_blinking.” We are going to define a verification goal to prove that the system exhibits this behavior. To help us, we defined a couple of “helper functions” to create this verification goal.
Get_sysml_state returns the SysML_state from “sa.”
State_changed takes a variable “sa” and “ex_m” and determines if the SysML_state will change if “my_step” is called. The <> symbol is not equal in Ocaml and IML.
So, we use these functions to create our verification goal. Verify that if Error_state, then state_changed is always true, meaning the SysML_state always changes.
The verify function evaluates all parameters and attributes across all the SysML_states algebraically, NOT statistically, or through random sampling. If verify returns Proved, we know the Boolean function is true for all parameters and attributes.
Unfortunately, when we called this verify function, it returned Refuted with a counter-example. The counter-example pointed out that if the system is in the “off” SysML_state and with the power off, it will not change SysML_states. Of course, that makes perfect sense, so we modified our verify function to ensure we only consider when the power is on.
So now we have two constraints: Power is on & we are in an Error_state. When we ran this function, we again received Refuted. When we dig into the counter-example, we see that the SysML_state = “Yellow_on” AND the clock has stopped.
We can review the behavior of the “Yellow_on” SysML state. The state “Yellow_on” only happens after “Green_on” and the system stays in the “Yellow_on” state for 2 seconds before transitioning to “Red_on.” In the case where the clock has stopped, the system will never transition from “Yellow_on” because, without a clock, the controller will never register 2 seconds elapsing. We also notice that the system never checks the status of the system, including checking for errors. To correct this issue, we must add a “do action,” like most other states, to check for errors explicitly. Below you can see where we added the “do action” for the “Yellow_on” SysML_state along with a comment.
By adding the “do action,” the “yellow_on_to_red_on” transition function will evaluate to true if an error is detected OR if 2 seconds elapse.
After identifying this issue with the design, and correcting it, we re-ran the verify function, and it returned Proved.
This process helped us identify two significant issues with the design that could easily have existed in the production code and appeared intermittently, where some traffic lights have a perpetually “yellow_on” light. Not only would this be costly to maintain in the field, but it also would be a significant safety concern, as perpetual “yellow_on” is not compliant with US traffic laws. Motorists would handle this case in unpredictable ways.
Conclusion
I am excited about our progress, but we are just getting started. Today you can use the approach outlined in the blog post and verify your own SysML v2 models, but we are working to make that process much easier. We are building tooling to use the SysML v2 API to export SysML v2 models as JSON and automatically convert them to IML. We also plan to leverage our integration of the Large Language Models to enable a natural language interface for creating verification goals and synthesizing SysML v2 that is correct. To discuss this work, please get in touch with me at Jamie@imandra.ai, or look for me at the next OMG members meeting.
Appendix A: Traffic Light SysML v2
package Traffic_light {
    
    import ISQ::*;
    import ISQBase::*;
    import Time::*;
    import ScalarValues::*;
    import StringFunctions::*;
    import NumericalFunctions::*;
    import ScalarValues::*;
    import SI::*;
    
    port def Can_bus;
    port def Clock;
    port def Vehicle_sensor_port;
    port def Comm;
    
    enum def Light_state {
                lit;
                off;
                blinking;
                }
                      
    calc def Light_power { in light_state : Light_state;
           return : PowerValue = 
                     if light_state == Light_state::off ? 0 [W]
                        else if light_state == Light_state::lit ? 12 [W]
                        else if light_state == Light_state::blinking ? 8 [W]
                        else 0 [W];
           }
           
    calc def Radio_power { in radio_on : Boolean;
           return : PowerValue = 
                     if radio_on ? 4 [W]
                     else 0 [W];
           }
    calc light_power : Light_power;
    calc radio_power : Radio_power;
    
    
    constraint def MassConstraint {
        in partMasses : MassValue[0..*];
        in massLimit : MassValue;
            sum(partMasses) <= massLimit
            }
    assert constraint massConstraint : MassConstraint {
            in partMasses = (light_housing.mass, traffic_light_controller.mass, traffic_light_counter.mass, traffic_light_radio.mass);
            in massLimit = 25.0 [kg];
        }  
            
    constraint def PowerConstraint {
        in partPowers : PowerValue[0..*];
        in powerLimit : PowerValue;
            sum(partPowers) <= powerLimit
            }

    assert constraint powerConstraint : PowerConstraint {
            in partPower = (light_housing.light_inserts.green_light.power_usage,
                            light_housing.light_inserts.yellow_light.power_usage,
                            light_housing.light_inserts.red_light.power_usage,
                            light_housing.light_electronic_housing.power_usage,
                            traffic_light_controller.power_usage,
                            traffic_light_counter.power_usage,
                            traffic_light_radio.power_usage);                                       
            in powerLimit = 19.0 [W];
        }

    interface def vehicle_sensor_signal {
            end vehicle_sensor_out : Vehicle_sensor_port;
            end vehicile_sensor_in : ~Vehicle_sensor_port;
            }
    
    interface def clock_bus {
            end clock_out : Clock;
            end clock_in : ~Clock;
            }
    interface def comm_bus {
            end communications_out : Comm;
            end communications_in : ~Comm;
            }
    interface def light_control_bus {
            end light_control_out : Can_bus;
            end light_control_in : ~Can_bus;
            }  
            
    item def Power;
    item def state_message_item {
        attribute state_message : String;
    }
    port power_on;
    
    part def Light_housing {
        attribute mass : MassValue;
        part light_inserts [3]{
            attribute mass : MassValue;
        }
    }
    part def Light_electronics_housing {
        attribute mass : MassValue;
        attribute power_usage : PowerValue;
    }
    part def light {
        attribute color;
        attribute light_state : Light_state;
        attribute location : Integer;
        attribute mass : MassValue;
        attribute power_usage : PowerValue;
        port light_control_in : Can_bus;
        } 
    part light_housing {   
        attribute mass :>> mass = 3.0 [kg];
        part light_electronic_housing : Light_electronics_housing {
            attribute mass :>> mass = 3.0 [kg];
            attribute power_usage :>> power_usage = 0.2 [W];
        }
        
    part def light_insert {
        attribute mass : MassValue;
        part red_light : light;
        part yellow_light : light;
        part green_light : light;
    }
        part light_inserts [3] : light_insert {
            attribute mass :>> mass = 3.0 [kg];
            part red_light :>> red_light {
                attribute red :>> color;
                attribute location :>> location =  0;
                attribute :>> light_state = Light_state::off;
                attribute mass :>> mass = 4.0 [kg];
                attribute power_usage :>> power_usage = light_power(light_housing.light_inserts.red_light.light_state);


            }
            part yellow_light :>> yellow_light {
                attribute yellow :> color;
                attribute location :>> location =  1;
                attribute :>> light_state = Light_state::off;
                attribute mass :>> mass = 4.0 [kg];
                attribute power_usage :>> power_usage = light_power(light_housing.light_inserts.yellow_light.light_state);

            }
            part green_light :>> green_light {
                attribute green :> color;
                attribute location :>> location =  2;
                attribute :>> light_state = Light_state::off;
                attribute mass :>> mass = 4.0 [kg];
                attribute power_usage :>> power_usage = light_power(light_housing.light_inserts.green_light.light_state);

            }

        }
    }
    part def Controller {
        attribute power : Boolean;
        attribute error : Boolean;
        attribute error_code : Integer;
        attribute message_queue : String;
        attribute counter : Integer;
        attribute current_time : TimeInstantValue;
        attribute state_duration : DurationValue;
        attribute wait_duration : Natural;
        attribute yellow_on_time : Natural;
        attribute green_on_time : Natural;
        attribute red_on_time : Natural;
        attribute yellow_light_state : Light_state;
        attribute red_light_state : Light_state;
        attribute green_light_state : Light_state;
        port light_control_out : Can_bus;
        port communications_in : Comm;
        attribute mass : MassValue;
        attribute power_usage : PowerValue;
        
    }
    part def Vehicle_sensor{
        attribute vehicle_at_light : Boolean;
    }
    part def Counter {
        attribute register : Integer;
        attribute mass : MassValue;
        attribute power_usage : PowerValue;
    }
    part def Radio {
        attribute register : Integer;
        port communications_out : Comm;
        attribute trans : Boolean;
        attribute mass : MassValue;
        attribute power_usage : PowerValue;
    }
    part vehicle_sensor : Vehicle_sensor {
        port vehicle_sensor_out : Vehicle_sensor_port;
    }
    part traffic_light_controller : Controller{
            attribute yellow_on_time :>> yellow_on_time =  2 [s];
            attribute green_on_time :>> green_on_time =  30 [s];
            attribute red_on_time :>> red_on_time =  90 [s];
            attribute mass :>> mass = 0.8 [kg];
            attribute power :>> power = 2.0 [W];

            action power_up_test;
            action reset_wait_clk{
                      assign wait_duration := 0 [s];
                      }
            
            
            action turn_lights_off {
                      assign traffic_light_controller.green_light_state := Light_state::off;
                      assign light_housing.light_inserts.green_light.light_state := Light_state::off;
                      assign traffic_light_controller.yellow_light_state := Light_state::off;
                      assign light_housing.light_inserts.yellow_light.light_state := Light_state::off;
                      assign traffic_light_controller.red_light_state := Light_state::off;
                      assign light_housing.light_inserts.red_light.light_state := Light_state::off;
                      assign traffic_light_radio.trans := false;
            }            

            action turn_yellow_on {
                      perform action turn_lights_off;
                      perform action reset_wait_clock;
                      assign traffic_light_controller.yellow_light_state := Light_state::lit;
                      assign light_housing.light_inserts.yellow_light.light_state := Light_state::lit;
                      }
            action turn_green_on {
                      perform action turn_lights_off;
                      perform action reset_wait_clock;
                      assign traffic_light_controller.green_light_state := Light_state::lit;
                      assign light_housing.light_inserts.green_light.light_state := Light_state::lit;
                      }
            action turn_red_on {
                      perform action turn_lights_off;
                      perform action reset_wait_clock;
                      assign traffic_light_controller.red_light_state := Light_state::lit;
                      assign light_housing.light_inserts.red_light.light_state := Light_state::lit;
                      }

            action reset_error;
            action reset_wait_clock;

            action run_diagnostic{
                action update_error_code;
                action update_error;
                action send_error_sms {
                        assign traffic_light_radio.trans := true;
                        }
                }
            action check_status{
                action check_error;
                action read_message_queue{
                    attribute message_from_queue : String;
                }
                }
            action blink_red_light {
                      perform action turn_lights_off;
                      assign traffic_light_controller.red_light_state := Light_state::blinking;
                      assign light_housing.light_inserts.red_light.light_state := Light_state::blinking;
                      }
            action blink_yellow_light {
                      assign traffic_light_controller.yellow_light_state := Light_state::blinking;
                      assign light_housing.light_inserts.yellow_light.light_state := Light_state::blinking;
                      }
        
            port clock_in : Clock;
            port vehicle_sensor_in :Vehicle_sensor_port;
            }
       part traffic_light_counter : Counter{
            port clock_out : Clock;
            attribute mass :>> mass = 0.4 [kg];
            attribute power_usage :>> power_usage = 0.4 [W];
         }
       part traffic_light_radio : Radio{
            attribute mass :>> mass = 0.6 [kg];
            attribute trans :>> trans = false;
            attribute power_usage :>> power_usage = radio_power(traffic_light_radio.trans); 
         }
   
state traffic_light{
            entry;
            succession begin first start
                then off;    
                
            transition off_to_init
                first off 
                accept Power via power_on
                then init; 
                
            transition init_to_diagnostic
                first init
                accept when (traffic_light_controller.error == true)
                then diagnostic;
                
            transition diagnostic_to_red_blinking
                first diagnostic
                then red_blinking;

            transition operation_selection_to_init
                first operation_selection
                accept when (traffic_light_controller.error == true)
                then init;

            transition init_to_operation_selection
                first init
                accept when (traffic_light_controller.error == false)
                then operation_selection;
            
            transition operation_selection_to_stop_sign
                first operation_selection
                accept when ((traffic_light_controller.message_queue == "operating_mode.stop_sign")
                        and (traffic_light_controller.error == false))
                then stop_sign;  

            transition operation_selection_to_caution
                first operation_selection
                accept when ((traffic_light_controller.message_queue == "operating_mode.caution") 
                        and (traffic_light_controller.error == false))
                then caution;
                
            transition operation_selection_to_traffic_flow
                first operation_selection
                accept when ((traffic_light_controller.message_queue == "operating_mode.traffic_flow") 
                        and (traffic_light_controller.error == false))
                then traffic_flow;
            
            transition caution_to_yellow_blinking
                first caution
                then yellow_blinking;
                
            transition stop_sign_to_red_blinking
                first stop_sign
                then red_blinking;
                
            transition traffic_flow_to_red_on
                first traffic_flow
                accept when (traffic_light_controller.error == false)
                then red_on;

            transition red_on_to_green_on
                first red_on
                accept when (traffic_light_controller.wait_duration > traffic_light_controller.red_on_time) 
                        and (vehicle_sensor.vehicle_at_light == true)
                        and (traffic_light_controller.message_queue == "Safe_all_red")
                        and (traffic_light_controller.error == false)
                then green_on;
                
            transition red_on_to_traffic_flow
                first red_on
                accept when ((((traffic_light_controller.message_queue != "")
                        and (traffic_light_controller.message_queue != "Safe_all_red"))
                        or (traffic_light_controller.error == true)))
                then traffic_flow; 

            transition green_on_to_yellow_on
                first green_on
                accept when  (traffic_light_controller.wait_duration > traffic_light_controller.green_on_time
                        or (traffic_light_controller.error == true))
                then yellow_on;

            transition yellow_on_to_red_on
                first yellow_on
                accept when (traffic_light_controller.wait_duration > traffic_light_controller.yellow_on_time)
                then red_on;

            transition traffic_flow_to_operation_selection
                first traffic_flow
                accept when ((traffic_light_controller.message_queue != "")
                        or (traffic_light_controller.error == true))
                then operation_selection;    
                
            transition red_blinking_to_operation_selection
                first red_blinking
                accept when ((traffic_light_controller.message_queue != "")
                        or (traffic_light_controller.error == true))
                then operation_selection;
                
            transition yellow_blinking_to_operation_selection
                first yellow_blinking
                accept when ((traffic_light_controller.message_queue != "")
                        or (traffic_light_controller.error == true))
                then operation_selection;

    }      
             state off;
                
             state init{
                    entry traffic_light_controller.power_up_test;
                    do traffic_light_controller.check_status.check_error;
                    exit;
                    }
                    
             state diagnostic {
                    entry traffic_light_controller.run_diagnostic;
                    exit traffic_light_controller.reset_error;
                    }
                
             state operation_selection{
                    entry traffic_light_controller.check_status.check_error;
                    do traffic_light_controller.check_status;
                    exit;
                    }
             state stop_sign;
             
             state red_blinking {
                    entry traffic_light_controller.blink_red_light;
                    do traffic_light_controller.check_status.check_error;
                    exit;
                    }
                
                
             state caution;
             
             state yellow_blinking {
                    entry traffic_light_controller.blink_yellow_light;
                    do traffic_light_controller.check_status; 
                    exit;
                    }
                
             state traffic_flow {
                    entry traffic_light_controller.check_status;
                    exit;
                }
             
             state green_on {
                    entry traffic_light_controller.turn_green_on; 
                    do traffic_light_controller.check_status;
                    exit;
                }
                
             state yellow_on {
                     entry traffic_light_controller.turn_yellow_on;
                     do traffic_light_controller.check_status.check_error;
                     exit;
                }
             
             state red_on {
                     entry traffic_light_controller.turn_red_on;
                     do traffic_light_controller.check_status;
                     exit;
                }
            
    interface : clock_bus connect
            traffic_light_counter.clock_out to
            traffic_light_controller.clock_in;
    interface : vehicle_sensor_signal connect
            vehicle_sensor.vehicle_sensor_out to
            traffic_light_controller.vehicle_sensor_in;     
    interface : light_control_bus connect
            traffic_light_controller.light_control_out to
            light_housing.light_inserts.red_light.light_control_in;
    interface : light_control_bus connect
            traffic_light_controller.light_control_out to
            light_housing.light_inserts.yellow_light.light_control_in;
    interface : light_control_bus connect
            traffic_light_controller.light_control_out to
            light_housing.light_inserts.green_light.light_control_in;

}

Sysml
Automated Reasoning
Llm
Formal Verification
177

1



Imandra Inc.
Published in Imandra Inc.
149 followers
·
Last published May 8, 2025
Reasoning as a Service @ www.imandra.ai

Follow
Jamie Smith
Written by Jamie Smith
23 followers
·
3 following

Follow
Responses (1)
Creatixchu
Creatixchu
What are your thoughts?﻿
Cancel
Respond
MeddlingMonk
MeddlingMonk
May 24, 2024

You have some syntax errors in your SysMLv2 model. In the action "turn_lights_off" you use the :>> token to try to assign a value. That symbol is shorthand for the "redefine" keyword which isn't what you want here. Redefinition is for modifying…more
Reply
More from Jamie Smith and Imandra Inc.
Automated Reasoning for SysML v2 Part 2
Imandra Inc.
In
Imandra Inc.
by
Jamie Smith
Automated Reasoning for SysML v2 Part 2
Formally Verifying SysML v2 Constraints with Imandra
Nov 1, 2023
133


Automated Reasoning for SysML v2 Part 3
Imandra Inc.
In
Imandra Inc.
by
Jamie Smith
Automated Reasoning for SysML v2 Part 3
Using Imandra Region Decomposition to Gain Insights of SysML v2 Models.
Nov 28, 2023
36
1


Formalising the FIX Protocol in Imandra
Imandra Inc.
In
Imandra Inc.
by
Kostya Kanishev
Formalising the FIX Protocol in Imandra
Financial markets run on many distributed systems – interconnected with multiple loosely-specified protocols such as FIX, SWIFT and ITCH…
Jun 19, 2018
470
2


First steps with ImandraX
Imandra Inc.
In
Imandra Inc.
by
Samer Abdallah
First steps with ImandraX
This blog entry describes my experience of getting started with ImandraX using the VS Code ImandraX extension. I decided to take some…
May 8
50
1


See all from Jamie Smith
See all from Imandra Inc.
Recommended from Medium
The AI Bubble Is About To Burst, But The Next Bubble Is Already Growing
Will Lockett
Will Lockett
The AI Bubble Is About To Burst, But The Next Bubble Is Already Growing
Techbros are preparing their latest bandwagon.

Sep 14
8.6K
285


Docker Is Dead — And It’s About Time
Abhinav
Abhinav
Docker Is Dead — And It’s About Time
Docker changed the game when it launched in 2013, making containers accessible and turning “Dockerize it” into a developer catchphrase.

Jun 8
6.6K
180


I Handed ChatGPT $100 to Trade Stocks — Here’s What Happened in 2 Months.
Coding Nexus
In
Coding Nexus
by
Civil Learning
I Handed ChatGPT $100 to Trade Stocks — Here’s What Happened in 2 Months.
What happens when you let a chatbot play Wall Street? It’s up 29% while the S&P 500 lags at 4%.

Sep 2
3.9K
96


I have built around 300 agents, worked at 5 startups. Here’s what I learnt about AI Agent
Yashwanth Sai
Yashwanth Sai
I have built around 300 agents, worked at 5 startups. Here’s what I learnt about AI Agent
Lessons learnt after working with agents for over an year.

Aug 24
4.1K
157


Google Just Eliminated the AI Infrastructure Headache for $25/Month
Jannis
Jannis
Google Just Eliminated the AI Infrastructure Headache for $25/Month
Google just solved the biggest pain point for developers building AI solutions: the infrastructure complexity and cost barrier that comes…

Aug 2
3K
52


Apple is quietly rewriting iOS and it’s not in Swift or Objective-C
Devlink Tips
Devlink Tips
Apple is quietly rewriting iOS and it’s not in Swift or Objective-C
The hidden language shift happening inside Cupertino, why it matters, and what it means for your future apps.

Sep 15
1.3K
40


See more recommendations
Help
Status
About
Careers
Press
Blog
Privacy
Rules
Terms
Text to speech