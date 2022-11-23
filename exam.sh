#!/bin/bash
header_cookie="Cookie: sessionId=; UserKey="

# 以下变量不需要变化
header_accept="Accept: */*'"
header_accept_language="Accept-Language: zh-CN,zh;q=0.9"
header_access_control_allow_origin="Access-Control-Allow-Origin: *"
header_cache_control="Cache-Control: max-age=0"
header_connection="Connection: keep-alive"
header_content_type="Content-Type: application/json; charset=utf-8"
header_user_agent="User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"

function init() {
    os=$(uname)
    case $os in
    # macOS基本命令检测
    Darwin)
        which curl >/dev/null 2>&1 || {
            log "准备安装curl命令,具体命令"
            brew install curl || {
                error "brew install curl 执行失败"
                exit 1
            }
        }
        which jq >/dev/null 2>&1 || {
            log "准备安装jq命令..."
            brew install jq || {
                error "brew install jq 执行失败"
                exit 1
            }
        }
        return
        ;;
    Linux)
        # Centos 基本命令检测
        test -r /etc/redhat-release && grep "CentOS" /etc/redhat-release >/dev/null 2>&1 && {

            which curl >/dev/null 2>&1 || {
                log "准备安装curl命令"
                sudo yum -y install curl || {
                    error "sudo yum -y install curl 执行失败"
                    exit 1
                }
            }
            which jq >/dev/null 2>&1 || {
                log "准备安装jq命令..."
                sudo yum -y install jq || {
                    error "sudo yum -y install jq 执行失败"
                    exit 1
                }
            }
            return
        }
        # Ubuntu 基本命令检测
        lsb_release -a 2>/dev/null | grep "Ubuntu" >/dev/null 2>&1 && {
            which curl >/dev/null 2>&1 || {
                log "准备安装curl命令"
                sudo apt -y install curl || {
                    error "sudo apt -y install curl 执行失败"
                    exit 1
                }
            }
            which jq >/dev/null 2>&1 || {
                log "准备安装jq命令..."
                sudo apt -y install jq || {
                    error "sudo apt -y install jq 执行失败"
                    exit 1
                }
            }
            return
        }
        ;;

    esac
}

function main() {
    # 获取学生ID
    curl_student_id=$(curl 'http://jjxy.web2.superchutou.com/service/eduSuper/StudentinfoDetail/GetStudentDetailRegisterSet' -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    StuDetail_ID=$(echo "$curl_student_id" | jq '.Data[0].StuDetail_ID' | tr -d '"')
    StuID=$(echo "$curl_student_id" | jq '.Data[0].StuID' | tr -d '"')

    # 获取课程列表
    curl_std_curriculum_list=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Specialty/GetStuSpecialtyCurriculumList?StuDetail_ID=${StuDetail_ID}&IsStudyYear=1&StuID=${StuID}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    study_year_total=$(echo "$curl_std_curriculum_list" | jq '.Data.list | length')
    for ((i = 0; i < study_year_total; i++)); do

        StudyYear=$(echo "$curl_std_curriculum_list" | jq ".Data.list[$i].StudyYear")
        CuName=$(echo "$curl_std_curriculum_list" | jq ".Data.list[$i].CuName")
        echo "$((i + 1))、第${StudyYear}学期 ${CuName}"
    done

    # 确定考试序号
    echo
    echo 在选择之前,请先进入考试页面,计时开始后,再选择序号,并回车
    read -r -p "选择课程序号:" seq
    seq=$((seq - 1))
    std_curriculum_list=$(echo "$curl_std_curriculum_list" | jq ".Data.list[$seq]")
    curriculum_curriculum_id=$(echo "$std_curriculum_list" | jq ".Curriculum_ID")

    # 获取exam_id
    curl_exam_paper_id=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Question/GetStuStagePaperList?StuID=${StuID}&ExamPaperType=3&Curriculum_ID=${curriculum_curriculum_id}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    exam_paper_id=$(echo "$curl_exam_paper_id" | jq ".Data[$j].ExamPaper_ID")

    # 获取result_id
    curl_result_id=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Question/GetExamPaperQuestions?examPaperId=${exam_paper_id}&IsBegin=1&StuID=${StuID}&StuDetail_ID=${StuDetail_ID}&Examination_ID=0&Curriculum_ID=${curriculum_curriculum_id}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    set +x 
    if [ "$(echo "$curl_result_id" | jq '.Message' | tr -d '"')" == "verify" ]; then
        echo "需要在考试页面刷新进行验证,若刷新后依然需要验证,请重新登录以获取新cookie"
        exit 1
    fi
    result_id=$(echo "$curl_result_id" | jq '.Data.ResultId')

    # 获取答案
    curl_ans=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Question/GetExamPaperResult?busId=${exam_paper_id}&resultId=${result_id}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    c=0
    echo "$curl_ans" | jq | grep "\"Answer\":" | cut -d '"' -f 4 | while read -r line; do
        test "$line" = 1 && line="对"
        test "$line" = 0 && line="错"
        echo -n "${line} "
        c=$((c + 1))
        # 输出空行
        test "$((c % 5))" -eq 0 && echo
    done
}

init
main
