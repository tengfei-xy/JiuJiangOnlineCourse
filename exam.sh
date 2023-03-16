#!/bin/bash

# 指定Cookie
# 格式:header_cookie="Cookie: sessionId=48K50np1t2zoIp8etn1Md8u1Wn4A7f4l; UserKey=77E8sgV2ZhdE587Vxs0NQ6K87cAP06hj"
header_cookie="Cookie: "


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
    StuDetail_ID=$(echo "$curl_student_id" | jq -r '.Data[0].StuDetail_ID' )
    StuID=$(echo "$curl_student_id" | jq -r '.Data[0].StuID' )

    test "$StuDetail_ID" = "null" && { echo "cookie无效" ; exit 1; }

    # 获取课程列表
    curl_std_curriculum_list=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Specialty/GetStuSpecialtyCurriculumList?StuDetail_ID=${StuDetail_ID}&IsStudyYear=1&StuID=${StuID}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    study_year_total=$(echo "$curl_std_curriculum_list" | jq '.Data.list | length')
    for ((i = 0; i < study_year_total; i++)); do

        StudyYear=$(echo "$curl_std_curriculum_list" | jq ".Data.list[$i].StudyYear")
        CuName=$(echo "$curl_std_curriculum_list" | jq -r ".Data.list[$i].CuName" )
        echo "$((i + 1))、第${StudyYear}学期 ${CuName}"
    done

    # 确定考试序号
    echo
    echo 在选择之前,请先进入考试页面,计时开始后,再选择序号,并回车
    read -r -p "选择课程序号:" seq
    seq=$((seq - 1))
    std_curriculum_list=$(echo "$curl_std_curriculum_list" | jq ".Data.list[$seq]")
    curriculum_id=$(echo "$std_curriculum_list" | jq ".Curriculum_ID")

    # 获取exam_id
    curl_exam_paper_id=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Question/GetStuStagePaperList?StuID=${StuID}&ExamPaperType=3&Curriculum_ID=${curriculum_id}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    exam_paper_id=$(echo "$curl_exam_paper_id" | jq ".Data[0].ExamPaper_ID")

    # 获取result_id
    curl_result_id=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Question/GetExamPaperQuestions?examPaperId=${exam_paper_id}&IsBegin=1&StuID=${StuID}&StuDetail_ID=${StuDetail_ID}&Examination_ID=0&Curriculum_ID=${curriculum_id}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    if [ "$(echo "$curl_result_id" | jq -r '.Message')" == "verify" ]; then
        echo "需要在考试页面刷新进行验证,若刷新后依然需要验证,请重新登录以获取新cookie"
        exit 1
    fi
    result_id=$(echo "$curl_result_id" | jq '.Data.ResultId')

    # 获取 阶段测评答案
    curl_exam_result=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Question/GetExamPaperResult?busId=${exam_paper_id}&resultId=${result_id}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    exam_question=$(echo "$curl_exam_result" | jq '.Data.QuestionType[].Question')
    
    # 获取 阶段测评的问题
    curl_question=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Question/GetExamPaperQuestions?examPaperId=${exam_paper_id}&type=2&StuDetail_ID=${StuDetail_ID}&StuID=${StuID}&Examination_ID=0&Curriculum_ID=${curriculum_id}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    # 已经在下列命令中删除了问题标题
    real_question_json=$(echo "$curl_question" | jq '.Data.QuestionType[].Question | del(.[].WExamPaperDetailID,.[].ExamPaperID,.[].QuestionStore_Name,.[].QuestionType_Name,.[].Level,.[].Body,.[].AnswerCount,.[].Answer,.[].QuestionData_ID,.[].QuestionData,.[].Sort,.[].Mark,.[].IsCollection,.[].ExamPaper_Detail_ID,.[].ExamPaperName,.[].AddTime,.[].Content,.[].QuestionStore_ID,.[].Source,.[].DoCounts,.[].RightCounts,.[].ChapterId,.[].Score,.[].DataContent,.[].SubQuestionType_ID,.[].SubScore,.[].Title)' | jq -s add)

    # 设置并计算分数
    score_1=$(echo "$curl_question" | jq '.Data.QuestionType[].TypeInfo | select(.QuestionType_ID==1) | .Sorce')
    test -z "$score_1" && score_1=0
    score_2=$(echo "$curl_question" | jq '.Data.QuestionType[].TypeInfo | select(.QuestionType_ID==2) | .Sorce')
    test -z "$score_2" && score_2=0
    score_3=$(echo "$curl_question" | jq '.Data.QuestionType[].TypeInfo | select(.QuestionType_ID==3) | .Sorce')
    test -z "$score_3" && score_3=0
    score_4=$(echo "$curl_question" | jq '.Data.QuestionType[].TypeInfo | select(.QuestionType_ID==4) | .Sorce')
    test -z "$score_4" && score_4=0
    score_all=0


    # echo "$curl_ans" | jq 

    real_question_length=$(echo "$real_question_json" | jq '. | length')
    for ((i = 0; i < real_question_length; i++)); do
        # 题目ID
        real_id=$(echo "$real_question_json" | jq ".[$i].ID")

        # 答案
        real_answare=$(echo "$exam_question" | jq ".[] | select(.ID==$real_id) | .Answer")
        real_question_type=$(echo "$real_question_json" | jq ".[$i].QuestionType_ID")

        # 题目名,需要获得不可以在jq中删除该字段，默认上方的命令已经删除了。
        # real_title=$(echo "$real_question_json" | jq ".[$i].Title" | tr -d "</p>")
        if [ -z "$real_answare" ]; then
            # echo "这题没有答案"
            case "$real_question_type" in
            1)
                real_answare="\"A\""
                ;;
            2)
                real_question_body=$(echo "$real_question_json" | jq ".[$i].Body" | grep "[[:upper:]]\"" -o | tr -d '\n' | tr '"' ',')
                real_answare="\"${real_question_body:-1}\""
                ;;
            4)
                real_answare="\"1\""
                ;;
            esac
        else
            case "$real_question_type" in
            1)
                score_all=$((score_1 + score_all))
                ;;
            2)
                score_all=$((score_2 + score_all))
                ;;
            3)
                score_all=$((score_3 + score_all))
                ;;
            4)
                score_all=$((score_4 + score_all))
                ;;
            esac
        fi
        echo "题号:$((i + 1)) 答案:${real_answare} 预计分数:${score_all}"
        real_answare_json="${real_answare_json}""$(echo "$real_question_json" | jq -r ".[] | select(.ID==$real_id) | .MyAnswer=${real_answare}")"

    done

    EndTime=1501
    real_answare_compain=$(echo "$real_answare_json" | jq -s '.' | jq "{resultId: ${result_id},list: .,EndTime: ${EndTime},StuDetail_ID: \"${StuDetail_ID}\",StuID: \"${StuID}\",Examination_ID: \"0\",Curriculum_ID: \"${curriculum_id}\"} | tostring" | sed 's/\\//g')
    real_answare_compain=${real_answare_compain##\"}
    real_answare_compain=${real_answare_compain%%\"}

    # echo "${real_answare_compain}"
    # 上传答案（仅上传，上传后自动保存答案，网页刷新后理论上可以查看已自动答题）
    curl_SubmitExamPractice=$(curl 'http://jjxy.web2.superchutou.com/service/eduSuper/Question/SubmitSimplePractice' --data-raw "$real_answare_compain" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "${header_cookie}; themeName=default" -H "$header_user_agent" --compressed --insecure -s)
    echo "保存答案结果:$(echo "$curl_SubmitExamPractice" | jq -r '.Message')"

    # 自动提交/交卷
    curl_SubmitExamPractice=$(curl 'http://jjxy.web2.superchutou.com/service/eduSuper/Question/SubmitExamPractice' --data-raw "$real_answare_compain" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "${header_cookie}; themeName=default" -H "$header_user_agent" --compressed --insecure -s)
    curl_SubmitExamPractice_result=$(echo "$curl_SubmitExamPractice" | jq -r '.Message')
    echo "提交试卷结果:${curl_SubmitExamPractice_result}"

}


init
main
