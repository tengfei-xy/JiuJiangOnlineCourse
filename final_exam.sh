#!/bin/bash

# 指定Cookie
# 格式:header_cookie="Cookie: sessionId=48K50np1t2zoIp8etn1Md8u1Wn4A7f4l; UserKey=77E8sgV2ZhdE587Vxs0NQ6K87cAP06hj"
header_cookie="Cookie: "

# 以下变量不需要变化
header_accept="Accept: */*"
header_accept_language="Accept-Language: zh-CN,zh;q=0.9"
header_access_control_allow_origin="Access-Control-Allow-Origin: *"
header_cache_control="Cache-Control: max-age=0"
header_connection="Connection: keep-alive"
header_content_type="Content-Type: application/json; charset=utf-8"
header_user_agent="User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"

function main() {
    # 获取学生ID
    curl_student_id=$(curl 'http://jjxy.web2.superchutou.com/service/eduSuper/StudentinfoDetail/GetStudentDetailRegisterSet' -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    StuDetail_ID=$(echo "$curl_student_id" | jq -r '.Data[0].StuDetail_ID')
    StuID=$(echo "$curl_student_id" | jq -r '.Data[0].StuID')

    test "$StuDetail_ID" = "null" && {
        echo "cookie无效"
        exit 1
    }

    # 获取课程列表
    curl_std_curriculum_list=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Specialty/GetStuSpecialtyCurriculumList?StuDetail_ID=${StuDetail_ID}&IsStudyYear=1&StuID=${StuID}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    study_year_total=$(echo "$curl_std_curriculum_list" | jq '.Data.list | length')
    for ((i = 0; i < study_year_total; i++)); do
        StudyYear=$(echo "$curl_std_curriculum_list" | jq ".Data.list[$i].StudyYear")
        CuName=$(echo "$curl_std_curriculum_list" | jq -r ".Data.list[$i].CuName")
        echo "$((i + 1))、第${StudyYear}学期 ${CuName}"
    done

    # 确定考试序号
    echo
    echo 在选择之前,请先进入阶段测评和期末考试页面,各计时开始后,再选择序号,并回车
    read -r -p "选择期末考试的科目序号:" seq
    seq=$((seq - 1))
    std_curriculum_list=$(echo "$curl_std_curriculum_list" | jq ".Data.list[$seq]")

    curriculum_id=$(echo "$std_curriculum_list" | jq ".Curriculum_ID")

    # 获取期末考试 的信息
    final_exam_info=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Question/GetFinalExamPaperView?StuDetail_ID=${StuDetail_ID}&Curriculum_ID=${curriculum_id}&Examination_ID=0" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    final_exam_paper_id=$(echo "$final_exam_info" | jq '.Data[0].ExamPaper_ID')
    final_examination_id=$(echo "$final_exam_info" | jq '.Data[0].Examination_ID')

    # 期末考试的基本信息
    curl_question=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Question/GetExamPaperQuestions?examPaperId=${final_exam_paper_id}&type=2&StuDetail_ID=${StuDetail_ID}&StuID=${StuID}&Examination_ID=0&Curriculum_ID=${curriculum_id}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    real_question_json=$(echo "$curl_question" | jq '.Data.QuestionType[].Question | del(.[].WExamPaperDetailID,.[].ExamPaperID,.[].QuestionStore_Name,.[].QuestionType_Name,.[].Level,.[].Body,.[].AnswerCount,.[].Answer,.[].QuestionData_ID,.[].QuestionData,.[].Sort,.[].Mark,.[].IsCollection,.[].ExamPaper_Detail_ID,.[].ExamPaperName,.[].AddTime,.[].Content,.[].QuestionStore_ID,.[].Source,.[].DoCounts,.[].RightCounts,.[].ChapterId,.[].Score,.[].DataContent,.[].SubQuestionType_ID,.[].SubScore,.[].Title)' | jq -s add)
    # 期末考试的基本信息 重新排序
    length=$(echo "$real_question_json" | jq 'length')
    for ((i = 0; i < length; i++)); do
        sort_json="${sort_json}""$(echo "$real_question_json" | jq "{ID:.[$i].ID,MyAnswer:.[$i].MyAnswer,Judge:.[$i].Judge,QuestionType_ID:.[$i].QuestionType_ID,FileJson:.[$i].FileJson}")"
    done
    real_question_json=$(echo "$sort_json" | jq -s '.')

    # 获取期末考试的结果ID
    # 注:仅有进入期末考试页面时才能获取到result_id
    curl_final_exam_result_id=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Question/GetExamPaperQuestions?examPaperId=${final_exam_paper_id}&IsBegin=1&StuID=${StuID}&StuDetail_ID=${StuDetail_ID}&Examination_ID=${final_examination_id}&Curriculum_ID=${curriculum_id}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    if [ "$(echo "$curl_final_exam_result_id" | jq '.Message' | tr -d '"')" == "verify" ]; then
        echo "需要在 期末考试 页面刷新进行验证,注:若刷新后依然需要验证,请重新登录以获取新cookie"
        exit 1
    fi
    final_exam_result_id=$(echo "$curl_final_exam_result_id" | jq '.Data.ResultId')
    # echo "期末考试的结果ID=${final_exam_result_id} "

    # 获取阶段测验的ExamPaper_ID
    curl_exam_paper_id=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Question/GetStuStagePaperList?StuID=${StuID}&ExamPaperType=3&Curriculum_ID=${curriculum_id}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    exam_paper_id=$(echo "$curl_exam_paper_id" | jq ".Data[0].ExamPaper_ID")

    # 获取阶段测验的result_id
    curl_exam_result_id=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Question/GetExamPaperQuestions?examPaperId=${exam_paper_id}&IsBegin=1&StuID=${StuID}&StuDetail_ID=${StuDetail_ID}&Examination_ID=0&Curriculum_ID=${curriculum_id}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    if [ "$(echo "$curl_exam_result_id" | jq '.Message' | tr -d '"')" == "verify" ]; then
        echo "需要在 阶段测评 页面刷新进行验证,注:若刷新后依然需要验证,请重新登录以获取新cookie"
        exit 1
    fi
    exam_result_id=$(echo "$curl_exam_result_id" | jq '.Data.ResultId')
    # echo "阶段测评的结果ID=${exam_result_id}"

    # 获取阶段测评的所有问题与答案
    curl_exam_result=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Question/GetExamPaperResult?busId=${exam_paper_id}&resultId=${exam_result_id}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    exam_question=$(echo "$curl_exam_result" | jq '.Data.QuestionType[].Question')

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
    real_answare_compain=$(echo "$real_answare_json" | jq -s '.' | jq "{resultId: ${final_exam_result_id},list: .,EndTime: ${EndTime},StuDetail_ID: \"${StuDetail_ID}\",StuID: \"${StuID}\",Examination_ID: \"${final_examination_id}\",Curriculum_ID: \"${curriculum_id}\"} | tostring" | tr -d "\\")
    real_answare_compain=${real_answare_compain##\"}
    real_answare_compain=${real_answare_compain%%\"}

    # 格式化输出答案
    echo
    echo "格式化答案:"
    echo "$real_answare_compain" | jq -r '.list[].MyAnswer' | while read -r line; do
        test "$line" = 1 && line="对"
        test "$line" = 0 && line="错"
        echo -n "${line} "
        c=$((c + 1))
        # 输出空行
        test "$((c % 5))" -eq 0 && echo
    done
    echo "预计保底分数:${score_all}"

    # 保存答案
    curl_SubmitExamPractice=$(curl 'http://jjxy.web2.superchutou.com/service/eduSuper/Question/SubmitSimplePractice' --data-raw "$real_answare_compain" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "${header_cookie}; themeName=default" -H "$header_user_agent" --compressed --insecure -s)
    echo "保存答案结果:$(echo "$curl_SubmitExamPractice" | jq -r '.Message')"

    total_seconds=$(echo "$curl_final_exam_result_id" | jq '.Data.PaperInfo.TotalSecends')
    if [ "$total_seconds" -ge 6300 ]; then
        echo "$((total_seconds - 6300 ))秒后才可提交答案"
        exit 0
    fi

    # 自动提交
    curl_SubmitExamPractice=$(curl 'http://jjxy.web2.superchutou.com/service/eduSuper/Question/SubmitExamPractice' --data-raw "$real_answare_compain" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "${header_cookie}; themeName=default" -H "$header_user_agent" --compressed --insecure -s)
    curl_SubmitExamPractice_result=$(echo "$curl_SubmitExamPractice" | jq -r '.Message')
    echo "提交试卷结果:${curl_SubmitExamPractice_result}"

    # 查看最后的得分
    final_exam_info=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Question/GetFinalExamPaperView?StuDetail_ID=${StuDetail_ID}&Curriculum_ID=${curriculum_id}&Examination_ID=0" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    echo "真实得分:$(echo "$final_exam_info" | jq '.Data[0].ExamScore')"
}

main
