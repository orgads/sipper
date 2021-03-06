
require 'driven_sip_test_case'

class TestPrackStoreAndDispatch < DrivenSipTestCase

  def setup
    super
    str = <<-EOF
    
    require 'sip_test_driver_controller'
    
    module TestPrackStoreAndDispatch_SipInline
      class Uas2xxController < SIP::SipTestDriverController
      
        transaction_usage :use_transactions=>false
        
        session_timer 500
        
        attr_accessor :inviteReq

        def on_invite(session)
          logd("Received INVITE in #{name}")
          @inviteReq = session.irequest
          r = session.create_response(183, "Session in progress", @inviteReq, true)
          session.send(r)
          r = session.create_response(180, "Ringing", @inviteReq, true)
          session.send(r)
          r = session.create_response(200, "OK", @inviteReq)
          session.send(r)
        end

        def on_prack(session)
          r = session.create_response(200, "OK")
          session.send(r)
        end
        
        def on_ack(session)
          session.invalidate
          session.flow_completed_for("TestPrackStoreAndDispatch")  
        end
        
        def order
          0
        end
      end
      
      class Uac2xxController < SIP::SipTestDriverController
        transaction_usage :use_transactions=>false        
        session_timer 500
        
        def start
          r = Request.create_initial("invite", "sip:nasir@sipper.com", :p_session_record=>"msg-info")
          u = create_udp_session(SipperConfigurator[:LocalSipperIP], SipperConfigurator[:LocalTestPort])
          u.send(r)
          logd("Sent a new INVITE from #{name}")
        end
     
        def on_trying_res(session)
        end

        def on_provisional_res(session)
          logd("Received provisional response ")
           response = session.iresponse
           if (response.rseq )
              logd("Sending prack")
              session.create_and_send_prack
           end
        end

        def on_success_res(session)
          logd("Received response in #{name}")
          response = session.iresponse

          if (response.get_request_method == "PRACK")
             logd("Received prack response")
          else
            session.create_and_send_ack 
            session.invalidate
          end
        end
        
      end
    end
    EOF
    define_controller_from(str)
    set_controller("TestPrackStoreAndDispatch_SipInline::Uac2xxController")
  end
  
  
  def test_prack
    self.expected_flow = ["> INVITE", "< 183", "> PRACK", "< 200", "< 180", "> PRACK", "< 200 {2,2}", "> ACK"]
    start_controller
    verify_call_flow(:out)
    self.expected_flow = ["< INVITE", "> 183", "< PRACK", "> 200", "> 180", "< PRACK", "> 200 {2,2}", "< ACK"]
    
    verify_call_flow(:in)
  end
  
end


